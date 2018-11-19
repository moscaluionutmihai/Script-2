--  -------------------------- CVS -----------------------------
--  $Source: /cvs/cvsvoms_ng/ORA_POS_PROCESSING/packages/tools_pkg.sql,v $
--  $Revision: 1.9.72.1 $
--  $Date: 2014-05-14 16:06:42 $
--  $Author: enemtisor $
--  ------------------------------------------------------------
CREATE OR REPLACE PACKAGE tools_pkg AS
   --  ============================================================
   --  Script name       : sh_curtime
   --  database          : ORACLE SQL
   --  Author            : LBE
   --  Creation date     :
   --  Description       : Returns the GMT timestamp 
   --                    :
   --  Modification date : 22/06/2009
   --                by  : MAN
   --  Description       : Patch for CFS 42567 : Now the function returns the 
   --                    :  GMT timestamp instead of local timestamp (error due
   --                    :  to Altran migration)
   --  Code review date  : 
   --                by  : 
   --  ============================================================
   FUNCTION sh_curtime
      RETURN NUMBER;

   --  ============================================================
   --  Script name      :  TimeCurrentInt8.sql
   --  database         :  ORACLE SQL
   --  Author           :  LBE
   --  creation date    :
   --  Description      :  Return time milisecond UTC
   --                   :
   --  code review date :  08/01/2007
   --                by :  NTR
   --  ============================================================
   FUNCTION TimeCurrentInt8
      RETURN NUMBER;

   --  ============================================================
   --  Script name      :  TimeCurrentInt8TruncHour.sql
   --  database         :  ORACLE SQL
   --  Author           :  ACV
   --  creation date    :
   --  Description      :  Return time milisecond UTC Hour Truncation
   --                   :
   --  ============================================================
   FUNCTION TimeCurrentInt8TruncHour
      RETURN NUMBER;

   --  ============================================================
   --  Script name      :  TimeCurrentInt8TruncDay.sql
   --  database         :  ORACLE SQL
   --  Author           :  ACV
   --  creation date    :
   --  Description      :  Return time milisecond UTC Day Truncation
   --                   :
   --  ============================================================
   FUNCTION TimeCurrentInt8TruncDay
      RETURN NUMBER;

   --  ============================================================
   --  Script name      :  TimeDiffSeconds.sql
   --  database         :  ORACLE SQL
   --  Author           :
   --  creation date    :
   --  Description      :  Return number of second
   --                   :
   --  code review date : 08/01/2007
   --                by : NTR
   --  ============================================================
   FUNCTION TimeDiffSeconds (
         p_Time1 TIMESTAMP
      ,  p_Time2 TIMESTAMP
      )
      RETURN PLS_INTEGER;

   --  ============================================================
   --  Script name      :  TimeFromSeconds.sql
   --  database         :  ORACLE SQL
   --  Author           :
   --  creation date    :
   --  Description      :  Return time using only by second
   --                   :
   --  code review date :  08/01/2007
   --                by :  NTR
   --  ============================================================
   FUNCTION TimeFromSeconds(
         p_Seconds NUMBER
      )
      RETURN TIMESTAMP;

   --  ============================================================
   --  Script name      :  TimeInt8ToDateGMT.sql
   --  database         :  ORACLE SQL
   --  Author           :  DST
   --  creation date    :  2006/12/07
   --  Description      :  Return time milisecond GMT
   --                   :
   --  code review date :  08/01/2007
   --                by :  NTR
   --  ============================================================
   FUNCTION TimeInt8ToDateGMT(
         p_Milliseconds NUMBER
      )
      RETURN TIMESTAMP;

   --  ============================================================
   --  Script name      :  TimeInt8ToDateLcl.sql
   --  database         :  ORACLE SQL
   --  Author           :  DST
   --  creation date    :  2006/12/07
   --  Description      :  Return time milisecond LCL
   --                   :
   --  code review date :  08/01/2007
   --                by :  NTR
   --  ============================================================
   FUNCTION TimeInt8ToDateLcl(
         p_Milliseconds NUMBER
      )
      RETURN TIMESTAMP; -- LOCAL TIME

   --  ============================================================
   --  Script name      :  TimeInt8ToDates.sql
   --  database         :  ORACLE SQL
   --  Author           :  LBE
   --  creation date    :  28/11/2006
   --  Description      :  Transform an integer NUMBER(19) to DateTime Type
   --                   :
   --  code review date :  08/01/2007
   --                by :  NTR
   --  ============================================================
   PROCEDURE TimeInt8ToDates (
         p_Milliseconds NUMBER
      -- Returned variables
      ,  r_localTime    OUT TIMESTAMP -- LOCAL TIME
      ,  r_UTC          OUT TIMESTAMP -- UTC
      );

   --  ============================================================
   --  Script name      :  TimeToInt8.sql
   --  database         :  ORACLE SQL
   --  Author           :  LBE
   --  creation date    :
   --  Description      :  Transform a Time type from dateTime format to NUMBER(19) integer
   --                   :
   --  code review date : 08/01/2007
   --                by : NTR
   --  ============================================================
   FUNCTION TimeToInt8(
         p_Time DATE
      )
      RETURN NUMBER;

   --  ============================================================
   --  Script name       :  TimeZoneOffset.sql
   --  Database          :  ORACLE
   --  Author            :  LBE
   --  Creation date     :
   --  Description       :  Get difference calendar according the geographic
   --                    :   time zone
   --  Modification date :  05/03/2009
   --                by  :  MAN
   --  Description       :  The time zone offset will be computed basing on the
   --                    :   server time zone rather than using the local
   --                    :   session time zone
   --  Code review date  :  08/01/2007
   --                by  :  NTR
   --  ============================================================
   FUNCTION TimeZoneOffset
      RETURN PLS_INTEGER;

   --  ============================================================
   --  Script name      :  min_paramDate.sql
   --  database         :  ORACLE SQL
   --  Author           :  LFA
   --  creation date    :  14/11/2006
   --  Description      :  Get the min date for global parameters to be reset
   --  code review date :  08/01/2007
   --                by :  NTR
   --  ============================================================
   FUNCTION min_paramDate
      RETURN NUMBER;

   --  ============================================================
   --  Script name      :
   --  database         :  ORACLE SQL
   --  Author           :  spect
   --  creation date    :
   --  Description      :  tool used to return days number from 12th December 1899
   --  code review date :
   --                by :
   --  ============================================================
   FUNCTION InformixDaysNumber(
         pDate TIMESTAMP
      )
      RETURN PLS_INTEGER;

END tools_pkg;

/

CREATE OR REPLACE PACKAGE BODY tools_pkg AS
   FUNCTION min_paramDate
      RETURN NUMBER AS
      v_i_gmt NUMBER(19);
   BEGIN
      -- Renvoi de l'heure UTC en millisecondes;
      v_i_gmt := (sh_curtime - 3600) * 1000; -- current time - 3600 s
      RETURN v_i_gmt;
   END min_paramDate;

   FUNCTION TimeCurrentInt8
      RETURN NUMBER AS
   BEGIN
      --  Return time milisecond UTC
      RETURN sh_curtime * 1000;
   END TimeCurrentInt8;

    FUNCTION TimeCurrentInt8TruncHour
        RETURN NUMBER AS 
        v_curentTimeSec  NUMBER;      
    BEGIN
        v_curentTimeSec := sh_curtime;
        RETURN ((v_curentTimeSec - MOD(v_curentTimeSec, 3600)) * 1000 );
    END TimeCurrentInt8TruncHour;

    FUNCTION TimeCurrentInt8TruncDay
        RETURN NUMBER AS 
        v_curentTimeSec  NUMBER;
    BEGIN
        v_curentTimeSec := sh_curtime;
        RETURN (((v_curentTimeSec - MOD(v_curentTimeSec, (3600 * 24)) - 1 ) * 1000 ));
    END TimeCurrentInt8TruncDay;

   PROCEDURE TimeInt8ToDates (
         p_Milliseconds NUMBER
      -- Returned variables
      ,  r_localTime    OUT TIMESTAMP -- LOCAL TIME
      ,  r_UTC          OUT TIMESTAMP -- UTC
      ) AS
   BEGIN
      r_localTime := TimeFromSeconds(p_Milliseconds / 1000 + TimeZoneOffset); -- LOCAL TIME
      r_UTC       := TimeFromSeconds(p_Milliseconds / 1000); -- UTC
      RETURN;
   END TimeInt8ToDates;

   FUNCTION TimeInt8ToDateGMT(
         p_Milliseconds NUMBER
      )
      RETURN TIMESTAMP -- GMT
    AS
   BEGIN
      RETURN TimeFromSeconds(p_Milliseconds / 1000); -- GMT
   END TimeInt8ToDateGMT;

   FUNCTION TimeInt8ToDateLcl(
         p_Milliseconds NUMBER
      )
      RETURN TIMESTAMP -- LOCAL TIME
    AS
   BEGIN
      RETURN TimeFromSeconds(p_Milliseconds / 1000 + TimeZoneOffset); -- LOCAL TIME
   END TimeInt8ToDateLcl;

   FUNCTION sh_curtime
      RETURN NUMBER AS
   BEGIN
      RETURN TimeDiffSeconds(   SYS_EXTRACT_UTC(SYSTIMESTAMP)
                              , TO_TIMESTAMP('1970/01/01','YYYY/MM/DD')
                             );
   END;

   FUNCTION TimeFromSeconds(
         p_Seconds NUMBER
      )
      RETURN TIMESTAMP AS
      v_interval INTERVAL DAY(9) TO SECOND(0);
      v_time     TIMESTAMP;
   BEGIN
      v_interval := numToDsInterval(p_seconds,
                                    'SECOND');
      v_time     := v_interval +
                    TO_TIMESTAMP('01/01/1970 0:0:0',
                                 'DD/MM/YYYY HH24:MI:SS');
      RETURN v_time;
   END TimeFromSeconds;

   FUNCTION TimeToInt8(
         p_Time DATE
      )
      RETURN NUMBER AS

      v_i_date NUMBER;
   BEGIN
      v_i_date := TimeDiffSeconds(p_Time,
                                  TO_TIMESTAMP('1970/01/01',
                                               'YYYY/MM/DD'));
      -- Return the milisecond found
      RETURN(v_i_date - TimeZoneOffset) * 1000;
   END TimeToInt8;

   FUNCTION TimeDiffSeconds (
         p_Time1 TIMESTAMP
      ,  p_Time2 TIMESTAMP
      )
      RETURN PLS_INTEGER AS

      v_difference   INTERVAL DAY(9) TO SECOND(0);
      v_diff_seconds PLS_INTEGER;
      v_days         PLS_INTEGER;
      v_hours        PLS_INTEGER;
      v_minutes      PLS_INTEGER;
      v_seconds      PLS_INTEGER;

   BEGIN
      v_difference := p_Time1 - p_Time2;

      --extract days from interval
      v_days := extract(DAY FROM v_difference);
      --extract hours
      v_hours := extract(hour FROM v_difference);
      --extract minutes
      v_minutes := extract(minute FROM v_difference);
      --extract seconds
      v_seconds := extract(SECOND FROM v_difference);
      --calculate difference in seconds
      v_diff_seconds := v_days * 86400 + v_hours * 3600 + v_minutes * 60 +
                        v_seconds;

      -- Return number of second
      RETURN sign(v_diff_seconds) * v_diff_seconds;
   END TimeDiffSeconds;

   FUNCTION TimeZoneOffset
      RETURN PLS_INTEGER AS
      v_tz_mins   PLS_INTEGER;
      v_tz_hours  PLS_INTEGER;
      v_tz_offset TIMESTAMP WITH TIME ZONE;
      v_seconds   PLS_INTEGER;
   BEGIN
      -- get time zone offset
      SELECT to_timestamp_tz(tz_offset(SESSIONTIMEZONE),'TZH:TZM')
        INTO v_tz_offset
        FROM DUAL;

      -- extract value of hours from given offset
      v_tz_hours := extract(timezone_hour FROM v_tz_offset);

      -- extract value of hours from given offset
      v_tz_mins := extract(timezone_minute FROM v_tz_offset);

      -- convert given offset to seconds
      v_seconds := v_tz_hours * 3600 + v_tz_mins * 60;

      RETURN v_seconds;
   END TimeZoneOffset;

   FUNCTION InformixDaysNumber(
         pDate TIMESTAMP
      )
      RETURN PLS_INTEGER AS
      v_difference INTERVAL DAY(9) TO SECOND;
      v_days       PLS_INTEGER;
   BEGIN
      v_difference := pDate - to_date('1899-12-31',
                                      'YYYY-MM-DD');
      v_days       := extract(DAY FROM v_difference);
      RETURN v_days;
   END InformixDaysNumber;


END tools_pkg;
/
