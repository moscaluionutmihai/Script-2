#!/bin/ksh
# CTR 119116 - WTA ListeAgent and ListeGroup scripts

# *** CAUTION : the parameters below must be set to your site values ***
dbuser=db_pos_wta
dbpasswd=db_pos_wta
dbSID=POS
#

sqlplus -S ${dbuser}/${dbpasswd}@${dbSID} << EOF

CREATE OR REPLACE PACKAGE support_pos_pkg AS

   PROCEDURE listeAgents;

END support_pos_pkg;

/

show errors;

CREATE OR REPLACE PACKAGE BODY support_pos_pkg AS

PROCEDURE listeAgents
  AS
      v_actorid       actor.actorid%TYPE;
      v_state         actor.state%TYPE;  
      v_profileid     actorprofile.profileid%TYPE;
      v_username      actoraliascategory.aliasname%TYPE;
      v_msisdn        actoraliascategory.aliasname%TYPE;
      v_firstname     actorinfo.firstname%TYPE;
      v_lastname      actorinfo.lastname%TYPE;
      v_address3      actorinfo.address3%TYPE;
      v_credit        balance.credit%TYPE;
      v_storm         balance.credit%TYPE;
      v_stormscratch  balance.credit%TYPE;
      v_balance       balance.credit%TYPE;
      v_profileLabel  label.label%TYPE;
      v_stateLabel    label.label%TYPE;
      v_balancecredit varchar2(50);
	  v_lockstate	  actorstate.state%TYPE;
	  v_lockstate2	  actorstate.state%TYPE;

      tmp_codingType  label.codingType%TYPE;
      tmp_lastUpdate  label.lastUpdate%TYPE;
      tmp_operError   smallint;
      tmp_return_code smallint;

      CURSOR c_actor IS
        SELECT actor.actorid, actor.state, actorprofile.profileid
        FROM actor, actorprofile
        WHERE   actor.actorid = actorprofile.actorid AND
                actor.group_q = 12 AND
                actor.state NOT IN (99,103)
        ORDER BY actor.actorid;

  BEGIN

    OPEN c_actor;
    LOOP
       FETCH c_actor
       INTO  v_actorid, v_state, v_profileid;
       EXIT WHEN c_actor%NOTFOUND;

       v_msisdn := '';
       v_username := '';
       v_firstname := '';
       v_lastname := '';
       v_address3 := '';
       v_profileLabel  := '';
       v_stateLabel  := '';
	   v_lockstate := '';
       v_credit := 0;

       BEGIN
         SELECT aliasname
         INTO v_username
         FROM actoraliascategory
         WHERE actorid = v_actorid
         AND aliascategory = 274
         AND rownum < 2;
       EXCEPTION
         WHEN NO_DATA_FOUND THEN v_username := '';
       END;

       BEGIN
         SELECT aliasname
         INTO v_msisdn
         FROM actoraliascategory
         WHERE actorid = v_actorid
         AND aliascategory = 270
         AND rownum < 2 ;
       EXCEPTION
       WHEN NO_DATA_FOUND THEN v_msisdn := '';
       END;
       
	   BEGIN
         SELECT SUSPENSION
         INTO v_lockstate
         FROM actorstate
         WHERE actorid = v_actorid
         AND COORDINATEID = 1001
         AND rownum < 2 ;
       EXCEPTION
       WHEN NO_DATA_FOUND THEN v_lockstate := '';
       END;
	   
	   BEGIN
         SELECT SUSPENSION
         INTO v_lockstate2
         FROM actorstate
         WHERE actorid = v_actorid
         AND COORDINATEID = 1002
         AND rownum < 2 ;
       EXCEPTION
       WHEN NO_DATA_FOUND THEN v_lockstate2 := '';
       END;

	   
       BEGIN
         SELECT firstname, lastname, address3
         INTO v_firstname, v_lastname, v_address3
         FROM actorinfo
         WHERE actorid = v_actorid;
       EXCEPTION
       WHEN NO_DATA_FOUND THEN
         BEGIN
           v_firstname := ''; 
           v_lastname := '';
           v_address3 := '';
         END;
       END;

       lang_label_pkg.getLblInLng ( v_profileid,
                                    388        ,
                                    'fre-DZ'   ,
                                     236       ,
                                     --- OUT parameters
                                     v_profileLabel  ,
                                     tmp_codingType  ,
                                     tmp_lastUpdate  ,
                                     tmp_operError   ,
                                     tmp_return_code ) ;

       lang_label_pkg.getLblInLng ( v_state,
                                    326       ,
                                    'fre-DZ'  ,
                                    236       ,
                                    --- OUT parameters
                                    v_stateLabel,
                                    tmp_codingType ,
                                    tmp_lastUpdate ,
                                    tmp_operError  ,
                                    tmp_return_code ) ;
                                    
       v_storm := NULL;
       v_stormscratch := NULL;
        
       FOR  rec IN
        (SELECT b.credit, b.balancetypeid 
         FROM  Account a, AccountAccess aa, balance b
         WHERE aa.actorId        = v_actorid
         AND   aa.accountId      = a.accountid
         AND   a.AccountId       = b.accountid
         AND a.state = 68 AND aa.state = 68 AND b.state = 68)
       LOOP
       
       IF (rec.balancetypeid = 2) THEN
           v_storm := rec.credit;
       ELSE
       IF (rec.balancetypeid = 300) THEN
           v_stormscratch := rec.credit;
       END IF; 
       END IF;     
            
       END LOOP;
       
       IF (v_storm IS NULL AND v_stormscratch IS NULL) THEN
           v_balancecredit := 'NULL Balance | NULL Balance';
       ELSIF (v_storm IS NULL) THEN
           v_balancecredit := 'NULL Balance | ' || v_stormscratch/100000;       
       ELSIF (v_stormscratch IS NULL) THEN
           v_balancecredit := v_storm/100000 || ' | NULL Balance';        
       ELSE
           v_balancecredit := v_storm/100000 || ' | ' || v_stormscratch/100000;         
       END IF;
       
       DBMS_OUTPUT.PUT_LINE( v_actorid || ' | ' ||
                                  NVL( v_stateLabel, '' ) || ' | ' ||
								  v_lockstate || ' | ' ||
								  v_lockstate2 || ' | ' ||
                                  v_profileLabel || ' | ' ||
                                 NVL( v_username , '' ) || ' | ' ||
                                 NVL( v_msisdn , '' ) || ' | ' ||
                                 NVL( v_firstname , '' ) || ' | ' ||
                                 NVL( v_lastname , '' ) || ' | ' ||
                                 NVL( v_address3 , '' ) || ' | ' ||
                                 v_balancecredit );                          

    END LOOP;
    CLOSE c_actor;
    RETURN;
  END;
  END support_pos_pkg;
/
  SHOW ERRORS;
/
EOF