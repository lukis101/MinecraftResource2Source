// The contents of this file is free and unencumbered software released into the
// public domain. For more information, please refer to <http://unlicense.org/>

import java.nio.file.Paths;
import java.nio.file.Path;
import java.nio.charset.StandardCharsets;
import java.io.Writer;
import java.util.Map;
import java.util.HashMap;
import java.util.List;
import java.util.ArrayList;
import java.util.Locale;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.io.Reader;
import java.io.FileReader;
import com.jogamp.opengl.GL;
import com.jogamp.opengl.GL2ES2;
import java.nio.*;
import org.json.*;

enum ScriptStatus {
    UNRESOLVED,
    IGNORE,
    RESOLVED,
}

// The path to assets extracted from base game or resource pack, should have folders "models" and "textures"
// should probably read "blockstates" for getting list of actually used(?) models instead of converting everything
static final String pathStr = "C:/Stuff/MCMP/assets/minecraft/";

static final Path baseFolder = Paths.get( pathStr );
static final Path textureFolder = baseFolder.resolve( "textures/" );
static final Path modelFolder = baseFolder.resolve( "models/" );

Path outFolder;
Path outModelFolder;
Path outTextureFolder;

class textureData
{
    String name;
    boolean resolved;
    PVector dimens;
}
static HashMap<String,ScriptStatus> modelFiles = new HashMap<String,ScriptStatus>();
static HashMap<String,PVector> textureDimens = new HashMap<String,PVector>();
static HashMap<String,String> textures = new HashMap<String,String>();

String resolveTexture( String texture )
{
    if( texture.charAt(0) == '#' )
        texture = resolveTexture( textures.get( texture.substring(1) ) );
    return texture;
}
PVector getTextureSize( String texture )
{
    String resolved = resolveTexture( texture );
    if( resolved.charAt(0) == '#' )
    {
        println( "Texture "+texture+" does not point to a file: "+resolved );
        return null;
    }

    if( !textureDimens.containsKey( resolved ) ) // Check if already exported
        ExportTexture( resolved );

    return textureDimens.get( resolved );
}
PVector resolveUV( String texture, float u, float v )
{
    PVector size = getTextureSize( texture );
    if( size == null )
        return new PVector( u, v );
    return new PVector( u*(1.f/size.x), v*(1.f/size.y) );
}

boolean parseModel( Path modelsPath, String modelFile )
{
    DecimalFormat df = new DecimalFormat( "0.00000", new DecimalFormatSymbols(Locale.ENGLISH) );
    Path modelPath = modelsPath.resolve( modelFile + ".json" );
    org.json.JSONObject jmodel;
    
    // Read the file
    try {
        Reader reader = Files.newBufferedReader( modelPath, StandardCharsets.UTF_8 );
        jmodel = new org.json.JSONObject( new JSONTokener(reader) );
        reader.close();
    }
    catch( IOException ioe ) {
        print( "Failed to read model source from " );
        println( modelPath.toString() );
        print( "Reason: " );
        println( ioe.getMessage() );
        return false;
    }

    // Useful fields for us
    boolean[] usedfields = new boolean[] {
        jmodel.has( "parent" ),
        jmodel.has( "textures" ),
        jmodel.has( "elements" ),
    };

    String parentfile = null;
    if( usedfields[0] ) // parent
    {
        // Parse parents first, check if they contain useful data
        parentfile = jmodel.getString( "parent" );
        usedfields[0] = parseModel( modelsPath, parentfile );
    }

    // Start parsing file
    if( usedfields[0] || usedfields[1] || usedfields[2] )
    {
        println( "New qc: "+modelFile );
        
        boolean realModel = false; // Defines a real model and not a template
        StringBuilder qcbuff = new StringBuilder(); // Write to memory until we figure correct file extension

        // Process textures first
        if( usedfields[1] ) // textures
        {
            org.json.JSONObject jtextures = jmodel.getJSONObject( "textures" );
            String[] texturekeys = org.json.JSONObject.getNames( jtextures );
            if( texturekeys != null )
            {
                qcbuff.append( "// JSON \"textures\":\n" );
                for( String texkey : texturekeys )
                {
                    String texvalue = jtextures.getString( texkey );
                    textures.put( texkey, texvalue );
                    println( "Define tex: "+texkey+" --> "+texvalue );
                    
                    if( texvalue.charAt(0) == '#' ) // Placeholder texture var
                    {
                        texvalue = "$texture_"+texvalue.substring(1)+'$';
                        texvalue = texvalue.replace( '#', '@' ); // .qc doesnt like '#' so change it
                    }
                    else
                        realModel = true; // Real model if uses atleast one texture *file*

                    qcbuff.append("$definevariable texture_").append(texkey).append(" \"").append(texvalue).append("\"\n");
                }
            }
        }
        
        String qcExtension = (realModel) ? ".qc" : ".qci";
        Path qcPath = outModelFolder.resolve( modelFile+qcExtension );
        
        try {
            Writer qcfile = Files.newBufferedWriter( qcPath, StandardCharsets.UTF_8 );
            qcfile.append( qcbuff );
            
            if( realModel )
            {
                qcfile.append( "\n// Main Template part 1\n" );
                qcfile.append( "$definevariable mdlname \"" ).append( modelFile ).append( "\"\n" );
                qcfile.append( "$include \"../modelbase_1.qci\"\n" );
            }
    
            // Include parent data
            if( usedfields[0] ) // has useful parents
            {
                qcfile.append( "\n// JSON \"parent\":\n" );
                qcfile.append( "$include \"" ).append( parentfile.substring(parentfile.indexOf('/')+1) ).append( ".qci\"\n" );
            }
    
            // Process model geometry
            if( usedfields[2] ) // elements
            {
                String relativename = modelFile.substring( modelFile.indexOf('/')+1 ); // remove "block\" part
                qcfile.append( "\n// JSON \"elements\":\n" );
                qcfile.append( "$definevariable mesh_main \"").append( relativename ).append( "\"\n" );
                
                qcfile.append( "\n// JSON \"elements[].faces[].texture\" list:\n" );
                qcfile.append( "$definemacro applytextures \\\\\n" );
                
                MCModel model = new MCModel();
                ArrayList modelTextures = new ArrayList(); // Different textures used in model
                org.json.JSONArray elements = jmodel.getJSONArray( "elements" );
                for( int i=0; i<elements.length(); i++ )
                {
                    org.json.JSONObject jelement = elements.getJSONObject( i );
                    org.json.JSONArray jfrom = jelement.getJSONArray( "from" );
                    org.json.JSONArray jto = jelement.getJSONArray( "to" );
                    org.json.JSONObject jfaces = jelement.getJSONObject( "faces" );
    
                    // Add element to model
                    PVector from = new PVector( (float)jfrom.getDouble(0), (float)jfrom.getDouble(2), (float)jfrom.getDouble(1) );
                    PVector to = new PVector( (float)jto.getDouble(0), (float)jto.getDouble(2), (float)jto.getDouble(1) );
                    MCModel.Element element = model.AddElement( from, to );
                    
                    // Add faces to element
                    String[] facenames = org.json.JSONObject.getNames( jfaces );
                    for( String facename : facenames )
                    {
                        org.json.JSONObject jfacedata = jfaces.getJSONObject( facename );
                        //String cullface = jfacedata.getString( "cullface" );
    
                        // Face texture
                        String texture = jfacedata.getString( "texture" );
                        if( texture.charAt(0) == '#' ) // List textures to QC
                        {
                            //if( !textures.containsKey(texture) )
                            if( !modelTextures.contains( texture ) )
                            {
                                //println( "New tex: "+texture );
                                //textures.put( texture, texture ); // Same for first deph level
                                modelTextures.add( texture );
                                texture = texture.replace( '#', '@' );
                                qcfile.append( "$renamematerial \"" ).append( texture )
                                      .append( "\" $texture_" ).append( texture.substring(1) ).append( "$ \\\\\n" );
                            }
                        }
                        
                        // Face UV
                        PVector uvfrom = new PVector( 0, 0 );
                        PVector uvto = new PVector( 1, 1 );
                        if( jfacedata.has( "uv" ) )
                        {
                            org.json.JSONArray juv = jfacedata.getJSONArray( "uv" );
                            uvfrom = resolveUV( texture, (float)juv.getDouble(0), (float)juv.getDouble(1) );
                            uvto = resolveUV( texture, (float)juv.getDouble(2), (float)juv.getDouble(3) );
                        }
                        element.AddFace( facename, texture, uvfrom, uvto );
                    }
                }
                model.UpdateHull(); // Finalize model data
    
                Path smdPath = outModelFolder.resolve( modelFile+".smd" );
                println( "New smd: "+modelFile );
                try {
                    Writer smdfile = Files.newBufferedWriter( smdPath, StandardCharsets.UTF_8 );
                    smdfile.write( "version 1\n" );
                    smdfile.write( "nodes\n" );
                    smdfile.write( "000 \"Cube\" -1\n" );
                    smdfile.write( "end\n" );
        
                    smdfile.write( "skeleton\n" );
                    smdfile.write( "time 0\n" );
                    smdfile.write( model.ToSMDBones( df ) );
                    smdfile.write( "end\n" );
                    
                    smdfile.write( "triangles\n" );
                    smdfile.write( model.ToSMD( df ) );
                    smdfile.write( "end" );
                    smdfile.close();
                }
                catch( IOException ioe ) {
                    print( "Failed to write " );
                    print( modelFile );
                    print( ".smd: " );
                    println( ioe.getMessage() );
                }
            }
    
            // Template part 2
            if( realModel )
            {
                qcfile.append( "\n$surfaceprop \"default\"\n" );
                qcfile.append( "$keyvalues { prop_data { \"base\" \"Plastic.Medium\" } }\n" );
    
                qcfile.append( "\n// Block Template\n" );
                qcfile.append( "$include \"../modelbase_2.qci\"\n" );
            }
            
            qcfile.close();
        }
        catch( IOException ioe ) {
            print( "Failed to write " );
            print( modelFile );
            print( ".qc: " );
            println( ioe.getMessage() );
        }
        return true;
    }
    else // nothing to parse
    {
        //println( "Not useful: "+modelPath );
        return false;
    }
}

void setup()
{
    outFolder = Paths.get( sketchPath("garrysmod/") );
    outModelFolder = outFolder.resolve( "modelsrc/" );
    outTextureFolder = outFolder.resolve( "materialsrc/" );
    
    print( "Destination folder: " );
    println( outFolder.toString() );
     // Just a test of one. Need to first make a full file list and keep track of processed ones when walking along the dependency tree
    parseModel( modelFolder, "block/magma" );
    exit();
}
