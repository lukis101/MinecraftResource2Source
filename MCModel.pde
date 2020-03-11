// The contents of this file is free and unencumbered software released into the
// public domain. For more information, please refer to <http://unlicense.org/>

import java.lang.*;

enum FaceDir {
    UP,
    DOWN,
    NORTH,
    EAST,
    SOUTH,
    WEST,
}
static final String endl = "\r\n";

class MCModel
{
    class Element // Cube
    {
        class Face
        {
            class Vertex
            {
                PVector pos;
                PVector uv;
                public Vertex( PVector pos, PVector uv )
                {
                    this.pos = pos;
                    this.uv = uv;
                }
                public String ToSMD( DecimalFormat df, PVector normal )
                {
                    StringBuilder builder = new StringBuilder();
                    builder.append( "0  " ); // Parent bone id
                    builder.append( df.format(pos.x) ).append(' ').append( df.format(pos.y) ).append(' ').append( df.format(pos.z) ).append( "  " ); // Vert pos
                    builder.append( df.format(normal.x) ).append(' ').append( df.format(normal.y) ).append(' ').append( df.format(normal.z) ).append( "  " ); // Vert normal
                    builder.append( df.format(uv.x) ).append(' ').append( df.format(uv.y) ); // Vert normal
                    return builder.toString();
                }
            } // class Vertex
            
            FaceDir dir = null;
            String tex = null;
            Vertex[] vert = null;
    
            public Face( FaceDir direction, String texture, PVector from, PVector to, PVector uvfrom, PVector uvto )
            {
                // Source engine vertices must go clockwise
                dir = direction;
                tex = texture;
                
                PVector corner1 = new PVector(0,0,0);
                PVector corner2 = new PVector(0,0,0);
                switch( dir )
                {
                  case UP:
                  case DOWN:
                    corner1.set( from.x, to.y, from.z );
                    corner2.set( to.x, from.y, from.z );
                    break;
                  case NORTH:
                  case SOUTH:
                    corner1.set( from.x, from.y, to.z );
                    corner2.set( to.x, from.y, from.z );
                    break;
                  case EAST:
                  case WEST:
                    corner1.set( from.x, from.y, to.z );
                    corner2.set( from.x, to.y, from.z );
                    break;
                }
                vert = new Vertex[] {
                    new Vertex( from, uvfrom ),
                    new Vertex( corner1, new PVector(uvfrom.x,uvto.y) ),
                    new Vertex( to, uvto ),
                    new Vertex( corner2, new PVector(uvto.x,uvfrom.y) )
                };
            }
            
            public String ToSMD( DecimalFormat df )
            {
                PVector normal = new PVector(0,0,0);
                switch( dir )
                {
                    case UP: normal.set( 0, 0, 1 ); break;
                    case DOWN: normal.set( 0, 0, -1); break;
                    case EAST: normal.add( -1, 0, 0 ); break;
                    case WEST: normal.add( 1, 0, 0 ); break;
                    case NORTH: normal.add( 0, -1, 0 ); break;
                    case SOUTH: normal.add( 0, 1, 0 ); break;
                }

                StringBuilder builder = new StringBuilder();
                builder.append( tex ).append( endl );
                builder.append( vert[0].ToSMD(df,normal) ).append( endl );
                builder.append( vert[3].ToSMD(df,normal) ).append( endl );
                builder.append( vert[2].ToSMD(df,normal) ).append( endl );
                builder.append( tex ).append( endl );
                builder.append( vert[2].ToSMD(df,normal) ).append( endl );
                builder.append( vert[1].ToSMD(df,normal) ).append( endl );
                builder.append( vert[0].ToSMD(df,normal) );
                return builder.toString();
            }
        } // class Face
        
        PVector from;
        PVector to;
        List<Face> faces;
        
        public Element( PVector from, PVector to )
        {
            this.from = from;
            this.to = to;
            faces = new ArrayList<Face>();
        }
        
        Face AddFace( String direction, String texture, PVector uvfrom, PVector uvto )
        {
            FaceDir dir = null;
            PVector facefrom = new PVector(0,0,0);
            PVector faceto = new PVector(0,0,0);
            if( direction.equals("up") )
            {
                dir = FaceDir.UP;
                facefrom.set( to.x, to.y, to.z );
                faceto.set( from.x, from.y, to.z );
            }
            else if( direction.equals("down") )
            {
                dir = FaceDir.DOWN;
                facefrom.set( to.x, from.y, from.z );
                faceto.set( from.x, to.y, from.z );
            }
            else if( direction.equals("north") )
            {
                dir = FaceDir.NORTH;
                facefrom.set( from.x, from.y, from.z );
                faceto.set( to.x, from.y, to.z );
            }
            else if( direction.equals("south") )
            {
                dir = FaceDir.SOUTH;
                facefrom.set( to.x, to.y, from.z );
                faceto.set( from.x, to.y, to.z );
            }
            else if( direction.equals("east") )
            {
                dir = FaceDir.EAST;
                facefrom.set( from.x, to.y, from.z );
                faceto.set( from.x, from.y, to.z );
            }
            else if( direction.equals("west") )
            {
                dir = FaceDir.WEST;
                facefrom.set( to.x, from.y, from.z );
                faceto.set( to.x, to.y, to.z );
            }
            else
                println( "Unknown face direction! "+direction );
                
            Face newface = new Face( dir, texture, facefrom, faceto, uvfrom, uvto );
            faces.add( newface );
            return newface;
        }

        public String ToSMD( DecimalFormat df )
        {
            StringBuilder builder = new StringBuilder();
            for( Face f : faces )
                builder.append( f.ToSMD(df) ).append( endl );
            return builder.toString();
        }
        public String ToSMDBone( DecimalFormat df )
        {
            StringBuilder builder = new StringBuilder();
            builder.append( df.format(center.x) ).append(' ') // Center pos
                   .append( df.format(center.y) ).append(' ')
                   .append( df.format(center.z) ).append( "  " );
            builder.append( df.format(0) ).append(' ') // Rotation
                   .append( df.format(0) ).append(' ')
                   .append( df.format(0) );
            return builder.toString();
        }
    } // class Element

    Map<String,String> textures = null;
    List<Element> elements = null;
    PVector min = new PVector( 0,0,0 );
    PVector max = new PVector( 0,0,0 );
    PVector center = new PVector( 0,0,0 );
    
    public MCModel()
    {
        textures = new HashMap<String,String>();
        elements = new ArrayList<Element>();
    }
    
    void AddTexture( String name, String path )
    {
        textures.put( name, path );
    }
    Element AddElement( PVector from, PVector to )
    {
        Element newelement = new Element( from, to );
        elements.add( newelement );
        return newelement;
    }

    public void UpdateHull()
    {
        boolean first = true;
        for( Element e : elements )
        {
            if( first )
            {
                min.set( min(e.from.x,e.to.x), min(e.from.y,e.to.y), min(e.from.z,e.to.z) );
                max.set( max(e.from.x,e.to.x), max(e.from.y,e.to.y), max(e.from.z,e.to.z) );
                first = false;
            }
            else
            {
                min.set( min(min.x,e.from.x,e.to.x), min(min.y,e.from.y,e.to.y), min(min.z,e.from.z,e.to.z) );
                max.set( max(max.x,e.from.x,e.to.x), max(max.y,e.from.y,e.to.y), max(max.z,e.from.z,e.to.z) );
            }
        }
        center.set( (min.x+max.x)/2, (min.y+max.y)/2, (min.z+max.z)/2 );
    }
    public String ToSMD( DecimalFormat df )
    {
        StringBuilder builder = new StringBuilder();
        for( Element e : elements )
            builder.append( e.ToSMD(df) );
        return builder.toString();
    }
    public String ToSMDBones( DecimalFormat df )
    {
        StringBuilder builder = new StringBuilder();
        int i = 0;
        for( Element e : elements )
            builder.append( i++ ).append( ' ' ).append( e.ToSMDBone(df) ).append( endl );
        return builder.toString();
    }
}
