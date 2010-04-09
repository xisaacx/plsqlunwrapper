create or replace java source named UTIL_ZIP
as
import java.io.*;
import java.util.zip.*;
import oracle.sql.*;
public class UTIL_ZIP
{
  public static String Inflate( byte[] src )
  {
    try
    {
      ByteArrayInputStream bis = new ByteArrayInputStream( src );
      InflaterInputStream iis = new InflaterInputStream( bis );
      StringBuffer sb = new StringBuffer();
      for( int c = iis.read(); c != -1; c = iis.read() )
      {
        sb.append( (char) c );
      }
      return sb.toString();
    } catch ( Exception e )
    {
    }
    return null;
  }
  public static byte[] Deflate( String src, int quality )
  {
    try
    {
      byte[] tmp = new byte[ src.length() + 100 ];
      Deflater defl = new Deflater( quality );
      defl.setInput( src.getBytes( "UTF-8" ) );
      defl.finish();
      int cnt = defl.deflate( tmp );
      byte[] res = new byte[ cnt ];
      for( int i = 0; i < cnt; i++ )
        res[i] = tmp[i];
      return res;
    } catch ( Exception e )
    {
    }
    return null;
  }
  public static void InflateBLOB( oracle.sql.BLOB src, oracle.sql.BLOB dst[] )
  {
    try
    {
      OutputStream bos = dst[0].getBinaryOutputStream();
      InflaterInputStream iis = new InflaterInputStream( src.getBinaryStream() );
      byte[] buffer = new byte[src.getBufferSize()];
      int cnt;
      while ((cnt = iis.read(buffer)) != -1) {
        bos.write(buffer,0,cnt);
      }
      iis.close();
      bos.close();
    } catch ( Exception e )
    {
    }
    return;
  }
  public static void DeflateBLOB( oracle.sql.BLOB src, oracle.sql.BLOB dst[] )
  {
    try
    {
      InputStream bis = src.getBinaryStream();
      DeflaterOutputStream dos = new DeflaterOutputStream( dst[0].getBinaryOutputStream() );
      byte[] buffer = new byte[src.getBufferSize()];
      int cnt;
      while ((cnt = bis.read(buffer)) != -1) {
        dos.write(buffer,0,cnt);
      }
      bis.close();
      dos.close();
    } catch ( Exception e )
    {
    }
    return;
  }
}
/
show err

alter java source UTIL_ZIP compile
/
show err


create or replace package kt_compress
is
function deflate(src in varchar2) return raw;
function deflate(src in varchar2, quality in number) return raw;
function inflate(src in raw) return varchar2;
procedure inflateBLOB(src in blob, dst in out blob);
procedure deflateBLOB(src in blob, dst in out blob);
end;
/
show err

create or replace package body kt_compress
is
function deflate(src in varchar2) return raw
is
begin
  return deflate(src, 6);
end;
function deflate(src in varchar2, quality in number) return raw
as language java
name 'UTIL_ZIP.Deflate(java.lang.String, int) return byte[]';
function inflate(src in raw) return varchar2
as language java
name 'UTIL_ZIP.Inflate(byte[]) return java.lang.String';
procedure inflateBLOB(src in blob, dst in out blob)
as language java
name 'UTIL_ZIP.InflateBLOB(oracle.sql.BLOB, oracle.sql.BLOB[])';
procedure deflateBLOB(src in blob, dst in out blob)
as language java
name 'UTIL_ZIP.DeflateBLOB(oracle.sql.BLOB, oracle.sql.BLOB[])';
end;
/
show err


