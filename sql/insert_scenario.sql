simphobe@SC01SERV03535:~/sscripts/sql$ cat param_Insert_SCENARIODEVCOMP.sql
SET SERVEROUTPUT ON;
SET ECHO ON;
SET linesize 150;
SET TIMING ON;


/

truncate table SERVICE_DEVICE_COMPATIBILITY;
/
set serveroutput off;
SET ECHO OFF;
EXIT;



simphobe@SC01SERV03535:~/sscripts/sql$ cat Insert_SCENARIODEVCOMP.sql
SET SERVEROUTPUT ON;
SET ECHO ON;
SET linesize 150;
SET TIMING ON;
DECLARE
--
                CURSOR List_scenario IS
        SELECT SERVICE_ID FROM SERVICE;
--
                scenario_id SERVICE.SERVICE_ID%TYPE;

--
--
 BEGIN
        dbms_output.enable(1000000);

        OPEN List_scenario;
        LOOP
          FETCH List_scenario into scenario_id;
          EXIT WHEN List_scenario%NOTFOUND;
                  dbms_output.put_line('Insert Line : ' || ' tac ' || '&1' || ' ,model ' || '&2' || ' ,brand ' || '&3' || ' ,scenario_id ' || to_char(scenario_id));
                  INSERT INTO SERVICE_DEVICE_COMPATIBILITY (ID,BRAND,MODEL,TAC,SERVICEID) values (hibernate_sequence.nextval,'&3','&2','&1',scenario_id);
          COMMIT;
        END LOOP;
--
        COMMIT;
--
            CLOSE List_scenario;
--
        EXCEPTION
        WHEN OTHERS THEN
          dbms_output.put_line ('{ERREUR} = '||to_char(SQLCODE));
          dbms_output.put_line ('{libelle}= '||substr(SQLERRM,1,150));
          dbms_output.put_line ('{STOP} / Erreur Oracle');
END;
/
set serveroutput off;
SET ECHO OFF;
EXIT;
