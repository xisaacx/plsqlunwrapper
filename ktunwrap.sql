create or replace package kt_unwrap
is
type varchar2_table is table of varchar2(32767);
function unwrap(name in varchar2, type in varchar2 default 'PACKAGE BODY', owner in varchar2 default user)
  return varchar2_table
  pipelined;
end;
/
show err

create or replace package body kt_unwrap
is
type raw_a is table of raw(32767) index by binary_integer;
S_SUB_FROM constant varchar2(1000) :=
  '3D6585B318DBE287F152AB634BB5A05F7D687B9B24C228678ADEA4261E03EB17'||
  '6F343E7A3FD2A96A0FE935561FB14D1078D975F6BC4104816106F9ADD6D5297E'||
  '869E79E505BA84CC6E278EB05DA8F39FD0A271B858DD2C38994C480755E4538C'||
  '46B62DA5AF322240DC50C3A1258B9C16605CCFFD0C981CD4376D3C3A30E86C31'||
  '47F533DA43C8E35E1994ECE6A39514E09D64FA5915C52FCABB0BDFF297BF0A76'||
  'B449445A1DF0009621807F1A82394FC1A7D70DD1D8FF139370EE5BEFBE09B977'||
  '72E7B254B72AC7739066200E51EDF87C8F2EF412C62B83CDACCB3BC44EC06936'||
  '6202AE88FCAA4208A64557D39ABDE1238D924A1189746B91FBFEC901EA1BF7CE';
S_SUB_TO constant varchar2(1000) :=
  '000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F'||
  '202122232425262728292A2B2C2D2E2F303132333435363738393A3B3C3D3E3F'||
  '404142434445464748494A4B4C4D4E4F505152535455565758595A5B5C5D5E5F'||
  '606162636465666768696A6B6C6D6E6F707172737475767778797A7B7C7D7E7F'||
  '808182838485868788898A8B8C8D8E8F909192939495969798999A9B9C9D9E9F'||
  'A0A1A2A3A4A5A6A7A8A9AAABACADAEAFB0B1B2B3B4B5B6B7B8B9BABBBCBDBEBF'||
  'C0C1C2C3C4C5C6C7C8C9CACBCCCDCECFD0D1D2D3D4D5D6D7D8D9DADBDCDDDEDF'||
  'E0E1E2E3E4E5E6E7E8E9EAEBECEDEEEFF0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF';
S_SUB_FROM_RAW constant raw(1000) := utl_raw.cast_to_raw(utl_raw.cast_to_varchar2(s_sub_from));
S_SUB_TO_RAW   constant raw(1000) := utl_raw.cast_to_raw(utl_raw.cast_to_varchar2(s_sub_to));
S_SHA1_DIGEST_LENGTH constant pls_integer := 40;
S_NEWLINE constant char := chr(10);
S_HEADER_LINES constant pls_integer := 20;

V_DEBUG pls_integer := 0;
procedure set_debug(p in pls_integer)
is
begin
  V_DEBUG := p;
end;
procedure PRINT(s in varchar2)
is
begin
  if V_DEBUG <> 0 then 
    dbms_output.put_line(s);
  end if;
end;

function dividesql(s in varchar2) return dbms_sql.varchar2a
is
  nl varchar2(10) := S_NEWLINE;
  len pls_integer := length(s);
  t   dbms_sql.varchar2a;
  i   pls_integer := 1;
  p   pls_integer := 1;
  np  pls_integer := 0;
begin
  loop
    exit when p > len;
    np := instr(s,nl,p);
    if np = 0 then
      t(i) := substr(s,p);
      exit;
    end if;
    t(i) := substr(s,p,np-p);
    p := np + 1;
    i := i + 1;
  end loop;
  return t;
end;

function get_wrapped_source(p_name in varchar2, p_type in varchar2, p_owner in varchar2 default user)
  return dbms_sql.varchar2a
is
  v_text all_source.text%type;
  j pls_integer := 0;
  t dbms_sql.varchar2a;
  s dbms_sql.varchar2a;
begin
  begin
    select text
      into v_text
      from all_source
     where owner = p_owner
       and name = p_name
       and type = p_type
       and line = 1
       and rtrim(substr(text,1,instr(text,S_NEWLINE)-1)) like '%wrapped';
  exception
    when no_data_found then
      raise_application_error(-20000, 'not found or wrapped');
  end;
  j := 1;
  for x in (select rownum, text
              from all_source
             where owner = p_owner
               and name = p_name
               and type = p_type
             order by line)
  loop
    t := dividesql(x.text);
    for i in 1..t.count loop
      if s.exists(j) then
        s(j) := s(j)||t(i);
      else
        s(j) := t(i);
      end if;
      j := j + 1;
    end loop;
    if substr(x.text, -1) <> S_NEWLINE then
      j := j - 1;
    end if;
  end loop;
  return s;
end;

function get_wrapped_body(x in dbms_sql.varchar2a) return dbms_sql.varchar2a
is
  y dbms_sql.varchar2a;
begin
  for i in (S_HEADER_LINES+1)..x.count loop
    y(i-S_HEADER_LINES) := x(i);
  end loop;
  return y;
end;

function base64_decode(x in dbms_sql.varchar2a) return dbms_sql.varchar2a
is
  y dbms_sql.varchar2a;
begin
  for i in 1..x.count loop
      y(i) := utl_encode.base64_decode(utl_raw.cast_to_raw(x(i)));
  end loop;
  return y;
end;

function get_wrapped_content(x in dbms_sql.varchar2a) return dbms_sql.varchar2a
is
  y dbms_sql.varchar2a := x;
begin
  for i in 1..x.count loop
    if i = 1 then
      y(1) := substr(x(1), S_SHA1_DIGEST_LENGTH+1);
    else
      y(i) := x(i);
    end if;
  end loop;
  return y;
end;

function translate_r_raw(x in raw) return raw
is
begin
  return utl_raw.translate(x,S_SUB_TO_RAW,S_SUB_FROM_RAW);
end;
function translate_r_raw_a(x in dbms_sql.varchar2a) return raw_a
is
  y raw_a;
begin
  for i in 1..x.count loop
    y(i) := translate_r_raw(utl_raw.cast_to_raw(utl_raw.cast_to_varchar2(x(i))));
  end loop;
  return y;
end;
procedure translate_r(x in dbms_sql.varchar2a, y in out blob)
is
  r raw_a;
begin
  r := translate_r_raw_a(x);
  for i in 1..r.count loop
    dbms_lob.append(y, r(i));
  end loop;
end;

procedure unwrap_source_to_blob(s in dbms_sql.varchar2a, p_b in out blob)
is
  v_a blob;
begin
  dbms_lob.createtemporary(v_a, true);
  dbms_lob.open(v_a, dbms_lob.lob_readwrite);
  translate_r(
    get_wrapped_content(
      base64_decode(
        get_wrapped_body(s)
      )
    )
  , v_a);
  kt_compress.inflateBLOB(v_a, p_b);
  dbms_lob.close(v_a);
end;

function blob2varchar2a(p_b in blob) return dbms_sql.varchar2a
is
  v_b_len pls_integer;
  j pls_integer := 0;
  v_amount pls_integer := 10000;
  v_offset pls_integer := 1;
  v_buffer            raw(20000);
  v_text_buffer       varchar2(32767);
  v_s dbms_sql.varchar2a;
  v_t dbms_sql.varchar2a;
begin
  v_b_len := dbms_lob.getlength(p_b);
  j := 1;
  for i in 1..ceil(v_b_len/v_amount) loop
    dbms_lob.read(p_b,v_amount,v_offset,v_buffer);
    v_text_buffer := utl_raw.cast_to_varchar2(v_buffer);
    v_t := dividesql(v_text_buffer);
    for k in 1..v_t.count loop
      if v_s.exists(j) then
        v_s(j) := v_s(j)||v_t(k);
      else
        v_s(j) := v_t(k);
      end if;
      j := j + 1;
    end loop;
    if substr(v_text_buffer, -1) <> S_NEWLINE then
      j := j - 1;
    end if;
    v_offset := v_offset + v_amount;
  end loop;
  return v_s;
end;

function unwrap_source(s in dbms_sql.varchar2a) return dbms_sql.varchar2a
is
  v_b blob;
  v_s dbms_sql.varchar2a;
begin
  dbms_lob.createtemporary(v_b, true);
  dbms_lob.open(v_b, dbms_lob.lob_readwrite);
  unwrap_source_to_blob(s, v_b);
  v_s := blob2varchar2a(v_b);
  dbms_lob.close(v_b);
  return v_s;
end;

function unwrap(name in varchar2, type in varchar2 default 'PACKAGE BODY', owner in varchar2 default user)
  return varchar2_table
  pipelined
is
  s dbms_sql.varchar2a;
begin
  s := unwrap_source(get_wrapped_source(name,type,owner));
  for i in 1..s.count loop
    pipe row(s(i));
  end loop;
  return;
end;

end;
/
show err


