// The contents of this file is free and unencumbered software released into the
// public domain. For more information, please refer to <http://unlicense.org/>

import java.nio.file.Files;

void ExportTexture( String texture )
{
        println( "ExportTexture: "+texture );
    Path sourceTexPath = textureFolder.resolve( texture+".png" );
    Path sourceMetaPath = textureFolder.resolve( texture+".png.mcmeta" );
    Path outTexPath = outTextureFolder.resolve( texture );
    PImage img = loadImage( sourceTexPath.toString() );
    if( img == null )
    {
        print( "Error loading texture: " );
        println( texture );
        return;
    }
    // Cache image dimensions for calculating uv-s
    PVector dimens = new PVector( img.width, img.height );
    textureDimens.put( texture, dimens );
    // Check for metadata
    if( Files.exists(sourceMetaPath) )
    {
        println( "Found meta for texture: "+texture );
    }
    
    // Export to tga
    img.save( outTexPath.toString()+".tga" );
    // Create matching .vmt meterial
    PrintWriter vmt = createWriter( outTexPath.toString()+".vmt" );
    vmt.println( "\"VertexLitGeneric\" {" );
    vmt.println( "}" );
    vmt.flush(); vmt.close();
}
