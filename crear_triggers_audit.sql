--CONSIDERACIONES:
--Cerciorarse que el nombre de todas las tablas sean de longitud max 25, ya que el nombre del trigger se forma a partir de este además de un prefijo 'A' y sufijo '_TRG'

SET SERVEROUTPUT ON
DECLARE
  NOMBRECOLUMNA   VARCHAR2(30);
  AUXCLAVES       VARCHAR2(120);
  AUXCLAVES2      VARCHAR2(120);

  CURSOR C_TABLAS IS 
      SELECT table_name FROM USER_TABLES WHERE TABLESPACE_NAME LIKE 'EJEMPLO' AND TABLE_NAME NOT IN ('AUDITORIA', 'OTRO') ORDER BY 1;

  CURSOR C_COLUMNS(NOMBRETABLA VARCHAR2) IS
      SELECT column_name FROM ALL_TAB_COLUMNS WHERE TABLE_NAME = NOMBRETABLA AND OWNER = 'EJEMPLO' AND COLUMN_NAME <> 'SHAPE';

  CURSOR C_PKS(NOMBRETABLA VARCHAR2) IS
      SELECT column_name FROM ALL_CONS_COLUMNS T1, ALL_CONSTRAINTS T2 
            WHERE T1.TABLE_NAME = T2.TABLE_NAME AND T1.OWNER = T2.OWNER AND T1.CONSTRAINT_NAME = T2.CONSTRAINT_NAME 
            AND T1.TABLE_NAME = NOMBRETABLA AND T1.OWNER = 'EJEMPLO' AND T2.CONSTRAINT_TYPE = 'P'; 

BEGIN

-- Recorremos el cursor con un bucle for - loop
    FOR i in C_TABLAS loop
      dbms_output.put_line( 'CREATE OR REPLACE TRIGGER A'||i.table_name||'_TRG' );
      dbms_output.put_line( 'BEFORE DELETE OR INSERT OR UPDATE' );
      dbms_output.put_line( 'ON '||i.table_name );
      dbms_output.put_line( 'REFERENCING OLD AS OLD NEW AS NEW' );
      dbms_output.put_line( 'FOR EACH ROW' );
      dbms_output.put_line( 'DECLARE' );
      dbms_output.put_line( ' HORA     VARCHAR2(8)  := TO_CHAR(SYSDATE,''HH24:MI:SS'');' );
      dbms_output.put_line( ' FECHA    DATE         := TO_DATE(TO_CHAR(SYSDATE,''DD/MM/YYYY''),''DD-MM-YYYY'');' );
      dbms_output.put_line( ' NOMTAB   VARCHAR2(30) := '''||i.table_name||''';' );
      dbms_output.put_line( ' LLAVES   VARCHAR2(200);' );
      dbms_output.put_line( ' MAQUINA  AUDITORIA.MAQUINA%TYPE;' );
      dbms_output.put_line( ' PROGRAMA VARCHAR2(64);' );
      dbms_output.put_line( ' SSID     NUMBER;' );
      dbms_output.put_line( ' NUMOPER  NUMBER;'||CHR(10) );      

      AUXCLAVES := '    LLAVES := ';
      AUXCLAVES2 := '    LLAVES := ';
      OPEN C_PKS(i.table_name);
        loop
          fetch C_PKS into NOMBRECOLUMNA;
          exit when C_PKS%NOTFOUND;
          AUXCLAVES := AUXCLAVES || ''''||NOMBRECOLUMNA||':''||:NEW.'||NOMBRECOLUMNA||'||'' ''';
          AUXCLAVES2 := AUXCLAVES2 || ''''||NOMBRECOLUMNA||':''||:OLD.'||NOMBRECOLUMNA||'||'' ''';
        end loop;
      CLOSE C_PKS;
      AUXCLAVES := AUXCLAVES || ';';
      AUXCLAVES2 := AUXCLAVES2 || ';';

      dbms_output.put_line( 'BEGIN' );
      dbms_output.put_line( ' SELECT machine, program, sid INTO MAQUINA, PROGRAMA, SSID FROM v$session WHERE audsid = (select userenv (''sessionid'') from dual);' );
      dbms_output.put_line( ' SELECT (CASE WHEN MAX(NUMEROOPERACION) IS NULL THEN 0 ELSE MAX(NUMEROOPERACION) END) +1 INTO NUMOPER FROM AUDITORIA;'||CHR(10) );

      dbms_output.put_line( ' --SI ES EVENTO DE INSERCION' );
      dbms_output.put_line( ' IF INSERTING THEN' );
      
      dbms_output.put_line( AUXCLAVES ||CHR(10));
      OPEN C_COLUMNS(i.table_name);
        loop
           fetch C_COLUMNS into NOMBRECOLUMNA;
           exit when C_COLUMNS%NOTFOUND;
           dbms_output.put_line( '    IF :NEW.'||NOMBRECOLUMNA||' IS NOT NULL THEN' );
           dbms_output.put_line( '      INSERT INTO AUDITORIA (NUMEROOPERACION, OPERACION, TABLA, REGISTROID, CAMPO, VALORNUEVO, USUARIO, MAQUINA, PROGRAMA, FECHA, HORA)' );
           dbms_output.put_line( '      VALUES (NUMOPER, ''INSERT'', NOMTAB, LLAVES, '''||NOMBRECOLUMNA||''', :NEW.'||NOMBRECOLUMNA||', USER, MAQUINA, PROGRAMA, FECHA, HORA);' );
           dbms_output.put_line( '    END IF;' );
        end loop;
      CLOSE C_COLUMNS;

      dbms_output.put_line( CHR(10)||'  --SI ES EVENTO DE MODIFICACION' );
      dbms_output.put_line( ' ELSIF UPDATING THEN' );
      dbms_output.put_line( AUXCLAVES2 ||CHR(10));
      OPEN C_COLUMNS(i.table_name);
        loop
           fetch C_COLUMNS into NOMBRECOLUMNA;
           exit when C_COLUMNS%NOTFOUND;
           dbms_output.put_line( '    IF :OLD.'||NOMBRECOLUMNA||' <> :NEW.'||NOMBRECOLUMNA||' THEN' );
           dbms_output.put_line( '      INSERT INTO AUDITORIA (NUMEROOPERACION, OPERACION, TABLA, REGISTROID, CAMPO, VALORANTIGUO, VALORNUEVO, USUARIO, MAQUINA, PROGRAMA, FECHA, HORA)' );
           dbms_output.put_line( '      VALUES (NUMOPER, ''UPDATE'', NOMTAB, LLAVES, '''||NOMBRECOLUMNA||''', :OLD.'||NOMBRECOLUMNA||', :NEW.'||NOMBRECOLUMNA||', USER, MAQUINA, PROGRAMA, FECHA, HORA);' );
           dbms_output.put_line( '    END IF;' );
        end loop;
      CLOSE C_COLUMNS;  

      dbms_output.put_line( CHR(10)||'  --SI ES EVENTO DE ELIMINACION' );
      dbms_output.put_line( ' ELSIF DELETING THEN' );
      dbms_output.put_line( AUXCLAVES2 ||CHR(10));
      OPEN C_COLUMNS(i.table_name);
        loop
           fetch C_COLUMNS into NOMBRECOLUMNA;
           exit when C_COLUMNS%NOTFOUND;
           dbms_output.put_line( '    IF :OLD.'||NOMBRECOLUMNA||' IS NOT NULL THEN' );
           dbms_output.put_line( '      INSERT INTO AUDITORIA (NUMEROOPERACION, OPERACION, TABLA, REGISTROID, CAMPO, VALORANTIGUO, USUARIO, MAQUINA, PROGRAMA, FECHA, HORA)' );
           dbms_output.put_line( '      VALUES (NUMOPER, ''DELETE'', NOMTAB, LLAVES, '''||NOMBRECOLUMNA||''', :OLD.'||NOMBRECOLUMNA||', USER, MAQUINA, PROGRAMA, FECHA, HORA);' );
           dbms_output.put_line( '    END IF;' );
        end loop;
      CLOSE C_COLUMNS;

      dbms_output.put_line( ' END IF;' );
      dbms_output.put_line( 'END;' );
      dbms_output.put_line( '/' );
      dbms_output.put_line( CHR(10)||'--------next trigger-------'||CHR(10) );
    END loop; 

END; 
