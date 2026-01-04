--------------------------------------------------------
--  DDL for Procedure TSA_SP_SCHOOL_CAL
--------------------------------------------------------
CREATE OR REPLACE PROCEDURE "TSADBA"."TSA_SP_SCHOOL_CAL" (CUR_TSA_QP_ALL in out REFCURSOR_PKG.REF_CURSOR, JOB_NAME in varchar2)
AUTHID Current_User    -- LAST UPDATE TIME: 20110617
IS
  TYPE PEND_RPTPOSTG_JOB_LINE IS RECORD(
    REQUEST_ID            TSA_JOB_REQUESTS.REQUEST_ID%TYPE,
    TSA_YEAR              TSA_RPTPOST_GENE_HIST.TSA_YEAR%TYPE,
    SCHOOL_CODE           TSA_RPTPOST_GENE_HIST.SCHOOL_CODE%TYPE,
    SCH_LEVEL             TSA_RPTPOST_GENE_HIST.SCH_LEVEL%TYPE,
    CLASS_LEVEL           TSA_RPTPOST_GENE_HIST.CLASS_LEVEL%TYPE,
    TSA_YEAR_STATUS       VARCHAR2(1 CHAR),
    CREATED_BY            TSA_JOB_REQUESTS.CREATED_BY%TYPE
  );

  r PEND_RPTPOSTG_JOB_LINE;

  TYPE cursor_temp IS REF CURSOR;
  CUR_PERCENTAGE          cursor_temp;
  CUR_REQUEST_JOB         cursor_temp;
  CUR_ITEM_CODE           cursor_temp;
  CUR_ASS_COUNT           cursor_temp;

  v_loghandle             UTL_FILE.file_type;
  v_exchandle             UTL_FILE.file_type;
  e_no_job_request        EXCEPTION;
  e_jobs_processing       EXCEPTION;
  E_ERROR_FOUND           EXCEPTION;
  v_count                 NUMBER := 0;
  v_count1                NUMBER := 0;
  v_sql_temp              VARCHAR2(18500);
  Error_Flag              VARCHAR2(1) := 'N';
  v_exc_file_name         VARCHAR2(100);
  v_data_file_name        VARCHAR2(100);
  exc_log_blob            BLOB;
  exc_log_bfile           BFILE;
  exc_log_size            NUMBER;

  Present                 BOOLEAN;
  FlENGTH                 NUMBER;
  bsize                   PLS_INTEGER;
  CURRENT_YEAR            VARCHAR2(4);
  RPTPOSTG_LOG_DIR        VARCHAR2(100);

  v_sch_id                bca_school.SCHOOL_ID%TYPE;
  v_sch_level             bca_school.SCHOOL_LEVEL%TYPE;
  v_sch_code              bca_school.SCHOOL_CODE%TYPE;
  v_class_level           bca_class.CLASS_LEVEL%TYPE;
  v_question_type         TSA_COMBINED_ANS.QUESTION_TYPE%TYPE;
  v_value                 VARCHAR2(25 CHAR);
  v_value1                VARCHAR2(25 CHAR);
  v_DATE                  VARCHAR2(20 CHAR);
  v_full_mark             NUMBER;
  go_on                   VARCHAR2(1 CHAR) := 'N';
  v_p3_flag               BOOLEAN := false;
  v_p6_flag               BOOLEAN := false;

  ret                     t_varchar_number;

BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM TSA_OUT_SCHOOL_RESULT WHERE RPT_TYPE = UPPER(''TSAPostRpt-004'') ';

  CURRENT_YEAR := TO_CHAR(SYSDATE,'YYYY');
  SELECT COUNT(1) INTO v_count FROM TSA_YEAR tsa_yr WHERE  STATUS = 'O' AND tsa_yr.TSA_YEAR = CURRENT_YEAR;
  IF v_count < 1 THEN
    CURRENT_YEAR := TO_CHAR(TO_NUMBER(CURRENT_YEAR) - 1);
  END IF;

  RPTPOSTG_LOG_DIR := 'RPTPOSTG_LOG_DIR_'|| CURRENT_YEAR;
  v_loghandle := UTL_FILE.fopen (RPTPOSTG_LOG_DIR, 'TSA_SP_SCHOOL_CAL' || '_' || TO_CHAR(SYSDATE,'YYYYMMDDHH24MI') || '.log', 'w');

  UTL_FILE.put_line(v_loghandle,'Job Log - RPTPOSTG - TSAPostRpt-004 - SCHOOL_CAL');
  UTL_FILE.put_line(v_loghandle,'  ');
  UTL_FILE.put_line(v_loghandle,'Job Start Date & Time: ' || TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI'));
  UTL_FILE.put_line(v_loghandle,'  ');

  -----------------------

  SELECT COUNT(table_name) INTO v_count FROM user_tables WHERE table_name ='PEND_RPTPOSTG_SCHOOL_JOB';
  IF v_count > 0 THEN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE PEND_RPTPOSTG_SCHOOL_JOB';
    EXECUTE IMMEDIATE 'DROP TABLE PEND_RPTPOSTG_SCHOOL_JOB';
  END IF;

  v_sql_temp := 'CREATE GLOBAL TEMPORARY TABLE PEND_RPTPOSTG_SCHOOL_JOB ON COMMIT PRESERVE ROWS '
              ||'AS SELECT B.REQUEST_ID, A.TSA_YEAR, A.SCHOOL_CODE, A.SCH_LEVEL, A.CLASS_LEVEL, C.STATUS TSA_YEAR_STATUS, B.CREATED_BY '
              ||'FROM TSA_RPTPOST_GENE_HIST A, TSA_JOB_REQUESTS B, TSA_YEAR C '
              ||'WHERE A.REQUEST_ID = B.REQUEST_ID AND A.TSA_YEAR = C.TSA_YEAR AND '
              ||'upper(A.POST_RPT_ID) = ''TSAPOSTRPT-004'' AND '
              ||'B.JOB_CODE =  ''RPTPOSTG'' AND '
              ||'B.REQUEST_STATUS = ''R''';
  EXECUTE IMMEDIATE v_sql_temp;

  SELECT COUNT(table_name) INTO v_count FROM user_tables WHERE table_name ='TEMP_OUT_SCHOOL_RESULT_SCH';
  IF v_count > 0 THEN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE TEMP_OUT_SCHOOL_RESULT_SCH';
    EXECUTE IMMEDIATE 'DROP TABLE TEMP_OUT_SCHOOL_RESULT_SCH';
  END IF;

  v_sql_temp := 'CREATE GLOBAL TEMPORARY TABLE TEMP_OUT_SCHOOL_RESULT_SCH '
              ||'('
              ||'REQUEST_ID    NUMBER(10), '
              ||'TSA_YEAR      VARCHAR2(4 CHAR), '
              ||'SCHOOL_CODE   VARCHAR2(25 CHAR), '
              ||'SCHOOL_LEVEL  VARCHAR2(10 CHAR), '
              ||'STATUS        VARCHAR2(250 CHAR) '
              ||')  ON COMMIT PRESERVE ROWS';
  EXECUTE IMMEDIATE v_sql_temp;

  SELECT COUNT(table_name) INTO v_count FROM user_tables WHERE table_name ='TEMP_PERCENTAGE';
  IF v_count > 0 THEN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE TEMP_PERCENTAGE';
    EXECUTE IMMEDIATE 'DROP TABLE TEMP_PERCENTAGE';
  END IF;

  v_sql_temp := 'CREATE GLOBAL TEMPORARY TABLE TEMP_PERCENTAGE '
              ||'('
              ||'TSA_YEAR        VARCHAR2(4 CHAR), '
              ||'SCHOOL_ID        NUMBER(10), '
              ||'CLASS_LEVEL      VARCHAR2(3 CHAR), '
              ||'SUBJECT_CODE     VARCHAR2(10 CHAR), '
              ||'NUMBER_STUDENT_A   NUMBER(10), '
              ||'NUMBER_STUDENT_B  NUMBER(10) '
              ||') '
              ||'ON COMMIT PRESERVE ROWS';
  EXECUTE IMMEDIATE v_sql_temp;

  SELECT COUNT(table_name) INTO v_count FROM user_tables WHERE table_name ='TEMP_AVERAGE';
  IF v_count > 0 THEN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE TEMP_AVERAGE';
    EXECUTE IMMEDIATE 'DROP TABLE TEMP_AVERAGE';
  END IF;

  v_sql_temp := 'CREATE GLOBAL TEMPORARY TABLE TEMP_AVERAGE '
              ||'('
              ||'TSA_YEAR         VARCHAR2(4 CHAR), '
              ||'SCHOOL_ID        NUMBER(10), '
              ||'CLASS_LEVEL      VARCHAR2(3 CHAR), '
              ||'SUBJECT_CODE     VARCHAR2(10 CHAR), '
              ||'DIMENSION        VARCHAR2(1000 CHAR), '
              ||'PAPER_CODE       VARCHAR2(25 CHAR), '
              ||'NUMBER_STUDENT   NUMBER(10), '
              ||'WEIGHT_NUM_OF_STUDENT  NUMBER(20,10), '
              ||'MAXIMUM_SCORE_A  NUMBER(13,10), '
              ||'SCHOOL_AVG_B     NUMBER(13,10), '
              ||'TOTAL_SCORE      NUMBER(20,10) '
              ||') '
              ||'ON COMMIT PRESERVE ROWS';
  EXECUTE IMMEDIATE v_sql_temp;

  ---- add for tsa_school
  SELECT COUNT(table_name) INTO v_count FROM user_tables WHERE table_name = 'TEMP_SCHOOL';
  if V_COUNT > 0 then
    EXECUTE IMMEDIATE 'TRUNCATE TABLE TEMP_SCHOOL';
    EXECUTE IMMEDIATE 'DROP TABLE TEMP_SCHOOL';
  END IF;

  v_sql_temp := 'CREATE GLOBAL TEMPORARY TABLE TEMP_SCHOOL '
              ||'('
              ||'SCHOOL_ID         NUMBER(10), '
              ||'SCHOOL_CODE       VARCHAR2(25 CHAR), '
              ||'SCHOOL_LEVEL      VARCHAR2(25 CHAR), '
              ||'STATUS            VARCHAR2(1 CHAR), '
              ||'TSA_FLAG          VARCHAR2(1 CHAR), '
              ||'TSA_YEAR          VARCHAR2(4 CHAR) '
              ||') '
              ||'ON COMMIT PRESERVE ROWS';
  EXECUTE IMMEDIATE v_sql_temp;

  select COUNT(1) into V_COUNT from TSA_SCHOOL_HIST where TSA_YEAR = R.TSA_YEAR;
  if V_COUNT > 0 then
    V_SQL_TEMP := 'Insert into TEMP_SCHOOL (SCHOOL_ID, SCHOOL_CODE, SCHOOL_LEVEL, STATUS, TSA_FLAG, TSA_YEAR) '
                ||'Select SCHOOL_ID, SCHOOL_CODE, SCHOOL_LEVEL, STATUS, TSA_FLAG, TSA_YEAR from tsa_school_hist '
                ||'where TSA_YEAR = :1 ';
    execute immediate V_SQL_TEMP using R.TSA_YEAR;
  else
    V_SQL_TEMP := 'Insert into TEMP_SCHOOL (SCHOOL_ID, SCHOOL_CODE, SCHOOL_LEVEL, STATUS, TSA_FLAG, TSA_YEAR) '
                ||'select SCHOOL_ID, SCHOOL_CODE, SCHOOL_LEVEL, STATUS, TSA_FLAG, :1 from BCA_SCHOOL ';
    execute immediate V_SQL_TEMP USING r.TSA_YEAR;
  end if;
  --END-- add for tsa_school

  v_sql_temp := 'select * from PEND_RPTPOSTG_SCHOOL_JOB  Order by REQUEST_ID';
  OPEN CUR_REQUEST_JOB FOR v_sql_temp;
  LOOP
    FETCH  CUR_REQUEST_JOB  INTO  r;
    EXIT WHEN CUR_REQUEST_JOB%NOTFOUND;
    Error_Flag := 'N';

    IF (r.SCH_LEVEL = 'P' and r.CLASS_LEVEL is null) THEN
      v_p3_flag := true;
      v_p6_flag := true;
    ELSIF (r.SCH_LEVEL = 'P' and r.CLASS_LEVEL = 'P3') THEN
      v_p3_flag := true;
    ELSIF (r.SCH_LEVEL = 'P' and r.CLASS_LEVEL = 'P6') THEN
      v_p6_flag := true;
    END IF;

    UTL_FILE.put_line(v_loghandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - Start the batch job: ' || r.REQUEST_ID);

    BEGIN
      v_exc_file_name := 'EXC_'|| r.REQUEST_ID || '_'||TO_CHAR(SYSDATE,'YYYYMMDDHH24MI') || '.log';
      v_exchandle := UTL_FILE.fopen (RPTPOSTG_LOG_DIR, v_exc_file_name, 'w');
    EXCEPTION
    WHEN OTHERS THEN
      UTL_FILE.put_line(v_loghandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - Could not create the Exception Report for the batch job: ' || r.REQUEST_ID);
      UTL_FILE.put_line(v_loghandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - End the batch job: ' || r.REQUEST_ID);
      UTL_FILE.put_line(v_loghandle,'  ');
      UTL_FILE.put_line(v_loghandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - ' ||'Exception Happen1: ' || SQLERRM);
      UTL_FILE.put_line(v_loghandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - Exception Happen1: '|| DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);

      UPDATE TSA_JOB_REQUESTS
      SET REQUEST_STATUS = 'F',
          ACTUAL_COMPLETE_DATE = TRUNC(SYSDATE,'MI'),
          LAST_UPDATE_DATE = TRUNC(SYSDATE,'MI')
      WHERE REQUEST_ID = r.REQUEST_ID;
      COMMIT;
      Error_Flag := 'Y';
    END;

    UTL_FILE.put_line(v_exchandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - Start the batch job: ' || r.REQUEST_ID);

    IF Error_Flag = 'N' THEN
    BEGIN
      go_on := 'N';
      if R.TSA_YEAR_STATUS <> 'O' then
        V_SQL_TEMP := 'SELECT COUNT(1) FROM TSA_RPT_SCH '
                    ||'WHERE TSA_YEAR = :1 '
                    ||'AND SCHOOL_ID = (SELECT SCHOOL_ID FROM TEMP_SCHOOL WHERE SCHOOL_CODE = :2 AND STATUS = ''A'') ';
        EXECUTE IMMEDIATE v_sql_temp INTO v_count USING r.TSA_YEAR, r.SCHOOL_CODE;

        IF v_count > 0 THEN
          v_sql_temp := 'INSERT INTO TEMP_OUT_SCHOOL_RESULT_SCH VALUES(:1, :2, :3, :4, ''C'') ';
          EXECUTE IMMEDIATE v_sql_temp USING r.REQUEST_ID, r.TSA_YEAR, r.SCHOOL_CODE, v_sch_level;
        else
          V_SQL_TEMP := 'SELECT school_level FROM TEMP_SCHOOL WHERE school_code = :1 AND STATUS = ''A'' ';
          EXECUTE IMMEDIATE v_sql_temp INTO v_sch_level USING r.SCHOOL_CODE;

          IF v_sch_level IS NULL THEN
            v_sch_level := r.SCH_LEVEL;
          END IF;

          V_SQL_TEMP := 'SELECT COUNT(distinct SCHOOL_ID) FROM TSA_RPT_SCH A '
                      ||'WHERE A.TSA_YEAR = to_char(:1) '
                      ||'AND EXISTS (SELECT 1 FROM TEMP_SCHOOL B WHERE B.SCHOOL_LEVEL = :2 AND B.SCHOOL_ID = A.SCHOOL_ID AND B.STATUS = ''A'' ) ';
          EXECUTE IMMEDIATE v_sql_temp INTO v_count USING r.TSA_YEAR, v_sch_level;

          V_SQL_TEMP := 'SELECT count(SCHOOL_ID) FROM TEMP_SCHOOL WHERE SCHOOL_LEVEL = :1 AND STATUS = ''A'' ';
          EXECUTE IMMEDIATE v_sql_temp INTO v_count1 USING v_sch_level;

          IF v_count = v_count1 THEN
             v_sql_temp := 'INSERT INTO TEMP_OUT_SCHOOL_SCH VALUES(:1, :2, :3, :4, ''C'') ';
             EXECUTE IMMEDIATE v_sql_temp USING r.REQUEST_ID, r.TSA_YEAR, r.SCHOOL_CODE, v_sch_level;
          ELSE
             go_on := 'Y';
          END IF;
        END IF;
      END IF;

      IF r.TSA_YEAR_STATUS = 'O' THEN
        if R.SCHOOL_CODE is not null then
          V_SQL_TEMP := 'SELECT school_level FROM TEMP_SCHOOL WHERE school_code = :1 AND STATUS = ''A'' ';
          EXECUTE IMMEDIATE v_sql_temp INTO v_sch_level using r.SCHOOL_CODE;

          IF v_sch_level IS NULL THEN
            v_sch_level := r.SCH_LEVEL;
          END IF;

          V_SQL_TEMP := 'SELECT COUNT(1) FROM TSA_RPT_SCH '
                      ||'WHERE TSA_YEAR = to_char(:1) '
                      ||'AND SCHOOL_ID = (SELECT SCHOOL_ID FROM TEMP_SCHOOL WHERE SCHOOL_CODE = :2 AND STATUS = ''A'') ';
          EXECUTE IMMEDIATE v_sql_temp INTO v_count using r.TSA_YEAR, r.SCHOOL_CODE;

          if V_COUNT > 0 then
            V_SQL_TEMP := 'DELETE FROM TSA_RPT_SCH '
                        ||'WHERE TSA_YEAR = to_char(:1) '
                        ||'AND SCHOOL_ID = (SELECT SCHOOL_ID FROM TEMP_SCHOOL WHERE SCHOOL_CODE = :2 AND STATUS = ''A'') '
                        ||'AND ((''P'' = :3 AND ((:4 IS NULL AND CLASS_LEVEL IN (''P3'',''P6'')) OR (:5 IS NOT NULL AND CLASS_LEVEL = :6))) OR (''S'' = :7 AND CLASS_LEVEL = ''S3'')) ';
            EXECUTE IMMEDIATE v_sql_temp using r.TSA_YEAR, r.SCHOOL_CODE, r.SCH_LEVEL, r.CLASS_LEVEL, r.CLASS_LEVEL, r.CLASS_LEVEL, r.SCH_LEVEL;
          END IF;
        else
          V_SQL_TEMP := 'SELECT COUNT(1) FROM TSA_RPT_SCH TRS '
                      ||'WHERE TRS.TSA_YEAR = to_char(:1) '
                      ||'AND EXISTS (SELECT 1 FROM TEMP_SCHOOL A WHERE A.SCHOOL_LEVEL = :2 AND A.SCHOOL_ID = TRS.SCHOOL_ID AND A.STATUS = ''A'') ';
          EXECUTE IMMEDIATE v_sql_temp INTO v_count using r.TSA_YEAR, r.SCH_LEVEL;

          if V_COUNT > 0 then
            V_SQL_TEMP := 'DELETE FROM TSA_RPT_SCH TRS '
                        ||'WHERE TRS.TSA_YEAR = to_char(:1) '
                        ||'AND EXISTS (SELECT 1 FROM TEMP_SCHOOL A WHERE A.SCHOOL_LEVEL = :2 AND A.SCHOOL_ID = TRS.SCHOOL_ID AND A.STATUS = ''A'') '
                        ||'AND ((''P'' = :3 AND ((:4 IS NULL AND CLASS_LEVEL IN (''P3'',''P6'')) OR (:5 IS NOT NULL AND CLASS_LEVEL = :6))) OR (''S'' = :7 AND CLASS_LEVEL = ''S3'')) ';
            EXECUTE IMMEDIATE v_sql_temp using r.TSA_YEAR, r.SCH_LEVEL, r.SCH_LEVEL, r.CLASS_LEVEL, r.CLASS_LEVEL, r.CLASS_LEVEL, r.SCH_LEVEL;
          END IF;
          v_sch_level := r.SCH_LEVEL;
        END IF;
        go_on := 'Y';
      END IF;
      v_class_level := r.CLASS_LEVEL;

      IF go_on = 'Y' THEN
        v_sql_temp := 'SELECT count(1) FROM TEMP_PERCENTAGE WHERE TSA_YEAR = :1 '
                    --||'AND ((''P'' = :2 AND (CLASS_LEVEL = ''P3'' OR CLASS_LEVEL = ''P6'')) OR (''S'' = :3 AND CLASS_LEVEL = ''S3'')) '
                    ||'AND ((''P'' = :2 AND ((:3 IS NULL AND CLASS_LEVEL IN (''P3'',''P6'')) OR (:4 IS NOT NULL AND CLASS_LEVEL = :5))) '
                    ||'OR (''S'' = :6 AND CLASS_LEVEL = ''S3'')) '
                    ||'AND SCHOOL_ID = 0 ';
        EXECUTE IMMEDIATE v_sql_temp INTO v_count USING r.TSA_YEAR, v_sch_level, v_class_level, v_class_level, v_class_level, v_sch_level;

        IF v_count <= 0 THEN
          v_sql_temp := 'INSERT INTO TEMP_PERCENTAGE '
                      ||'SELECT '
                      ||'TLUH.TSA_YEAR '
                      ||', 0 '
                      ||', TLUH.CLASS_LEVEL '
                      ||', TLUH.SUBJECT '
                      ||', COUNT(1) COUNTERA, 0 '
                      ||'FROM TSA_LOGIT_UL_HIST TLUH, TSA_LOGIT TL '
                      ||'WHERE TLUH.REQUEST_ID = TL.REQUEST_ID '
                      ||'AND ( '
                      --||' (''P'' = :1 AND (CLASS_LEVEL = ''P3'' OR CLASS_LEVEL = ''P6'')) '
                      ||'  (''P'' = :1 AND ((:2 IS NULL AND CLASS_LEVEL IN (''P3'',''P6'')) OR (:3 IS NOT NULL AND CLASS_LEVEL = :4))) '
                      ||'  OR '
                      ||'  (''S'' = :5 AND CLASS_LEVEL = ''S3'') '
                      ||') '
                      ||'AND TLUH.TSA_YEAR = :6 '
                      ||'GROUP BY TLUH.TSA_YEAR, TLUH.CLASS_LEVEL, TLUH.SUBJECT ';
          EXECUTE IMMEDIATE v_sql_temp USING v_sch_level, v_class_level, v_class_level, v_class_level, v_sch_level, r.TSA_YEAR;

          v_sql_temp := 'UPDATE TEMP_PERCENTAGE A SET A.NUMBER_STUDENT_B = '
                      ||'NVL((SELECT COUNTERB FROM ( '
                      ||'SELECT '
                      ||'TLUH.TSA_YEAR '
                      ||',TLUH.CLASS_LEVEL '
                      ||',TLUH.SUBJECT '
                      ||',COUNT(1) COUNTERB '
                      ||'FROM TSA_LOGIT_UL_HIST TLUH, TSA_LOGIT TL, TSA_BENCHMARK TB '
                      ||'WHERE TLUH.REQUEST_ID = TL.REQUEST_ID '
                      ||'AND TB.TSA_YEAR = TLUH.TSA_YEAR '
                      ||'AND '
                      ||'( '
                      ||'  (TLUH.CLASS_LEVEL = ''P3'' AND '
                      ||'    ( '
                      ||'      (TLUH.SUBJECT=''CHI'' AND TL.LOGIT_VALUE >=TB.P3CHI ) '
                      ||'      OR '
                      ||'      (TLUH.SUBJECT=''ENG'' AND TL.LOGIT_VALUE >=TB.P3ENG ) '
                      ||'      OR '
                      ||'      (TLUH.SUBJECT=''MATH'' AND TL.LOGIT_VALUE >=TB.P3MATH ) '
                      ||'    ) '
                      ||'  ) OR '
                      ||'  (TLUH.CLASS_LEVEL = ''P6'' AND '
                      ||'    ( '
                      ||'      (TLUH.SUBJECT=''CHI'' AND TL.LOGIT_VALUE >=TB.P6CHI ) '
                      ||'      OR '
                      ||'      (TLUH.SUBJECT=''ENG'' AND TL.LOGIT_VALUE >=TB.P6ENG ) '
                      ||'      OR '
                      ||'      (TLUH.SUBJECT=''MATH'' AND TL.LOGIT_VALUE >=TB.P6MATH ) '
                      ||'    ) '
                      ||'  )OR '
                      ||'  (TLUH.CLASS_LEVEL = ''S3'' AND '
                      ||'    ( '
                      ||'      (TLUH.SUBJECT=''CHI'' AND TL.LOGIT_VALUE >=TB.S3CHI ) '
                      ||'      OR '
                      ||'      (TLUH.SUBJECT=''ENG'' AND TL.LOGIT_VALUE >=TB.S3ENG ) '
                      ||'      OR '
                      ||'      (TLUH.SUBJECT=''MATH'' AND TL.LOGIT_VALUE >=TB.S3MATH ) '
                      ||'    ) '
                      ||'  ) '
                      ||') '
                      ||'AND TB.TSA_YEAR = :1 '
                      ||'AND ((''P'' = :2 AND (CLASS_LEVEL = ''P3'' OR CLASS_LEVEL = ''P6'')) OR (''S'' = :3 AND CLASS_LEVEL = ''S3'')) '
                      ||'GROUP BY TLUH.TSA_YEAR, TLUH.CLASS_LEVEL, TLUH.SUBJECT '
                      ||') B '
                      ||'WHERE A.TSA_YEAR = B.TSA_YEAR '
                      ||'AND A.CLASS_LEVEL = B.CLASS_LEVEL '
                      ||'AND A.SUBJECT_CODE = B.SUBJECT ),0) ';
          EXECUTE IMMEDIATE v_sql_temp USING r.TSA_YEAR, v_sch_level, v_sch_level;

            -- 6.9.3.1    Delete record that is already exist in the table
          Delete from TSA_RPT_SCH
          Where tsa_year = r.TSA_YEAR
          And School_id = 0
          --AND (('P' = v_sch_level AND (CLASS_LEVEL = 'P3' OR CLASS_LEVEL = 'P6')) OR ('S' = v_sch_level AND CLASS_LEVEL = 'S3')) ;
          AND (
            ('P' = v_sch_level AND ((v_class_level IS NULL AND CLASS_LEVEL IN ('P3','P6')) OR (v_class_level IS NOT NULL AND CLASS_LEVEL = v_class_level)))
            OR
            ('S' = v_sch_level AND CLASS_LEVEL = 'S3')
          );

          V_DATE := TRUNC(SYSDATE,'MI');
          v_sql_temp := 'INSERT INTO TSA_RPT_SCH '
                      ||'SELECT A.*, :1, :2, :3, :4 '
                      ||'FROM TEMP_PERCENTAGE A '
                      ||'WHERE SCHOOL_ID = 0 '
                      --||'AND ((''P'' = :5 AND (CLASS_LEVEL = ''P3'' OR CLASS_LEVEL = ''P6'')) OR (''S'' = :6 AND CLASS_LEVEL = ''S3'')) '
                      ||'AND ((''P'' = :5 AND ((:6 IS NULL AND CLASS_LEVEL IN (''P3'',''P6'')) OR (:7 IS NOT NULL AND CLASS_LEVEL = :8))) OR (''S'' = :9 AND CLASS_LEVEL = ''S3'')) '
                      ||'AND TSA_YEAR = :10 '; -- Added by Ady for Exception Happen: ORA-00001: unique constraint (TSADBA.TSA_RPT_SCH_PK) violated on 2012-05-22
          EXECUTE IMMEDIATE v_sql_temp USING V_DATE,r.CREATED_BY,V_DATE,r.CREATED_BY,v_sch_level,v_class_level,v_class_level,v_class_level,v_sch_level,r.TSA_YEAR;
        END IF;

        v_sql_temp := 'SELECT count(1) FROM TEMP_AVERAGE WHERE TSA_YEAR = :1'
                    --||'AND ((''P'' = :2 AND (CLASS_LEVEL = ''P3'' OR CLASS_LEVEL = ''P6'')) OR (''S'' = :3 AND CLASS_LEVEL = ''S3'')) '
                    ||'AND ((''P'' = :2 AND ((:3 IS NULL AND CLASS_LEVEL IN (''P3'',''P6'')) OR (:4 IS NOT NULL AND CLASS_LEVEL = :5))) OR (''S'' = :6 AND CLASS_LEVEL = ''S3'')) '
                    ||'AND SCHOOL_ID = 0 ';
        EXECUTE IMMEDIATE v_sql_temp INTO v_count USING r.TSA_YEAR, v_sch_level, v_class_level, v_class_level, v_class_level, v_sch_level;

        IF v_count <= 0 THEN
          IF (v_sch_level = 'P' AND (v_class_level IS NULL OR v_class_level = 'P3')) THEN
            v_sql_temp := 'INSERT INTO TEMP_AVERAGE '
                        ||'SELECT TSA_YEAR '
                        ||', 0 '
                        ||', CLASS_LEVEL '
                        ||', SUBJECT_CODE '
                        ||', DIMENSION '
                        ||', PAPER_CODE '
                        ||', COUNT(CANDIDATE_NO) NUM_STUDENTS '   --removed DISTINCT 20100726
                        ||', sum(WEIGHT) WEIGHT_NUM_STUDENTS '
                        ||', 0 '
                        --||', AVG(total_mark) AVERAGE '
                        ||', decode(sum(WEIGHT),0,0,sum(total_mark) / sum(WEIGHT)) AVERAGE '
                        ||', sum(total_mark) '
                        ||'FROM '
                        ||'( '
                        ||'SELECT TSA_YEAR, SCHOOL_ID, CLASS_LEVEL, SUBJECT_CODE, DIMENSION, PAPER_CODE, CANDIDATE_NO, SUM(total_mark)*WEIGHT TOTAL_MARK '
                        ||', WEIGHT '
                        ||'FROM ( '
                        ||'SELECT '
                        ||'TSA_YEAR '
                        ||', SCHOOL_ID '
                        ||', decode(CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',CLASS_LEVEL) CLASS_LEVEL '
                        ||', SUBJECT_CODE SUBJECT_CODE '
                        ||', substr(EXT_ITEM_CODE, instr(EXT_ITEM_CODE, ''T'') +3, 1) DIMENSION '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(PAPER_CODE, 1, 2) || SUBSTR(PAPER_CODE, 4), PAPER_CODE) PAPER_CODE '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(EXT_ITEM_CODE, 1, 1) || MATH_ITEM_CODE, EXT_ITEM_CODE) ITEM_CODE '
                        ||', (CANDIDATE_NO||PAPER_CODE) CANDIDATE_NO '
                        ||', sum(DECODE(scored_ans_mark,''U'',0,''Z'',0,scored_ans_mark))/COUNT(NVL(MARKER_SEQ,1)) total_mark '
                        ||', WEIGHT '
                        ||'from ( '
                        ||'select '
                        ||'TCM.TSA_YEAR '
                        ||', TCA.SCHOOL_ID '
                        ||', TCM.CLASS_LEVEL '
                        ||', TCM.SUBJECT_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) EXT_ITEM_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),3) MATH_ITEM_CODE '
                        ||', TCA.CANDIDATE_NO '
                        ||', TCM.PAPER_CODE '
                        ||', TCA.scored_ans_mark '
                        ||', TCA.MARKER_SEQ '
                        ||', NVL(TCA.WEIGHT,0) WEIGHT '
                        ||'FROM '
                        ||'TSA_DATA_CB_HIST TDCH '
                        ||', TSA_COMBINED_MASTER TCM '
                        ||', TSA_COMBINED_ANS TCA '
                        ||'WHERE '
                        ||'TDCH.REQUEST_ID = TCM.REQUEST_ID '
                        ||'AND TCM.COMBINED_MASTER_ID = TCA.COMBINED_MASTER_ID '
                        ||'AND TDCH.ACCEPTANCE = ''A'' '
                        ||'AND TDCH.AUTO_MARKED = ''Y'' '
                        ||'AND decode(TCM.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TCM.CLASS_LEVEL) = :sch_level '
                        ||'AND TCM.TSA_YEAR = :TSA_YEAR '
                        ||'AND TCA.INT_TYPE = ''OMR'' '     -- added for TechnicalSpec-RptBatchFunctSP_V9.5 (6.14.1, 6.14.5)
                        ||'AND TCM.CLASS_LEVEL = ''KS1'' '
                        ||'union all '
                        ||'select '
                        ||'TCM.TSA_YEAR '
                        ||', TCA.SCHOOL_ID '
                        ||', TCM.CLASS_LEVEL '
                        ||', TCM.SUBJECT_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) EXT_ITEM_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),3) MATH_ITEM_CODE '
                        ||', TCA.CANDIDATE_NO '
                        ||', TCM.PAPER_CODE '
                        ||', TCA.scored_ans_mark '
                        ||', TCA.MARKER_SEQ '
                        ||', NVL(TCA.WEIGHT,0) WEIGHT '
                        ||'FROM '
                        ||'TSA_COMBINED_MASTER TCM '
                        ||', TSA_COMBINED_ANS TCA '
                        ||'WHERE '
                        ||'0 = TCM.REQUEST_ID '
                        ||'AND TCM.COMBINED_MASTER_ID = TCA.COMBINED_MASTER_ID '
                        ||'AND decode(TCM.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TCM.CLASS_LEVEL) = :sch_level '
                        ||'AND TCM.TSA_YEAR = :TSA_YEAR '
                        ||'AND TCA.INT_TYPE = ''OMR'' '     -- added for TechnicalSpec-RptBatchFunctSP_V9.5 (6.14.1, 6.14.5)
                        ||'AND TCM.CLASS_LEVEL = ''KS1'' '
                        ||') '
                        ||'GROUP BY TSA_YEAR '
                        ||', SCHOOL_ID '
                        ||', decode(CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',CLASS_LEVEL) '
                        ||', SUBJECT_CODE '
                        ||', substr(EXT_ITEM_CODE, instr(EXT_ITEM_CODE, ''T'') +3, 1) '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(PAPER_CODE, 1, 2) || SUBSTR(PAPER_CODE, 4), PAPER_CODE) '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(EXT_ITEM_CODE, 1, 1) || MATH_ITEM_CODE, EXT_ITEM_CODE) '
                        ||', (CANDIDATE_NO||PAPER_CODE) '
                        ||', WEIGHT '
                        ||'UNION ALL '
                        ||'SELECT '
                        ||'TSA_YEAR TSA_YEAR '
                        ||', SCHOOL_ID SCHOOL_ID '
                        ||', decode(CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',CLASS_LEVEL) CLASS_LEVEL '
                        ||', SUBJECT_CODE SUBJECT_CODE '
                        ||', substr(EXT_ITEM_CODE, instr(EXT_ITEM_CODE, ''T'') +3, 1) DIMENSION '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(PAPER_CODE, 1, 2) || SUBSTR(PAPER_CODE, 4), PAPER_CODE) PAPER_CODE '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(EXT_ITEM_CODE, 1, 1) || MATH_ITEM_CODE, EXT_ITEM_CODE) ITEM_CODE '
                        ||', (CANDIDATE_NO||PAPER_CODE) CANDIDATE_NO '
                        ||', sum(DECODE(scored_ans_mark,''U'',0,''Z'',0,scored_ans_mark))/COUNT(NVL(MARKER_SEQ,1)) total_mark '
                        ||', WEIGHT '
                        ||'FROM ( '
                        ||'select '
                        ||'TCM.TSA_YEAR '
                        ||', TCA.SCHOOL_ID '
                        ||', TCM.CLASS_LEVEL '
                        ||', TCM.SUBJECT_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) EXT_ITEM_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),3) MATH_ITEM_CODE '
                        ||', TCM.PAPER_CODE '
                        ||', TCA.CANDIDATE_NO '
                        ||', TCA.scored_ans_mark '
                        ||', TCA.MARKER_SEQ '
                        ||', NVL(TCA.WEIGHT,0) WEIGHT '
                        ||'from '
                        ||'TSA_DATA_CB_HIST TDCH '
                        ||', TSA_COMBINED_MASTER TCM '
                        ||', TSA_COMBINED_ANS TCA , TSA_MS_QUESTION TMQ , tsa_ms tm  '
                        ||'WHERE '
                        ||'TDCH.REQUEST_ID = TCM.REQUEST_ID '
                        ||'AND TCM.COMBINED_MASTER_ID = TCA.COMBINED_MASTER_ID '
                        ||'AND SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) = TMQ.ITEM_CODE '
                        ||'AND EXTRACTVALUE(TMQ.OSM_MS_DTL, ''/ROOT/SHOW_IN_REPORT'') = ''Y'' '
                        ||'AND TDCH.ACCEPTANCE = ''A'' '
                        ||'AND TDCH.AUTO_MARKED = ''Y'' '
                        ||'AND decode(TCM.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TCM.CLASS_LEVEL) = :sch_level '
                        ||'AND TCM.TSA_YEAR = :TSA_YEAR '
                        ||'AND TCA.INT_TYPE = ''OSM'' '
                        ||'and tm.tsa_year = :TSA_YEAR '
                        ||'and tm.paper_code=tcm.paper_code '
                        ||'and tm.ms_id= tmq.ms_id '
                        ||'and decode(tm.subject_code,''EMATH'',''MATH'',''CMATH'',''MATH'',tm.subject_code) = tcm.subject_code '
                        ||'and tm.class_level = tcm.class_level '
                        ||'AND TCM.CLASS_LEVEL = ''KS1'' '
                        ||'union all '
                        ||'select '
                        ||'TCM.TSA_YEAR '
                        ||', TCA.SCHOOL_ID '
                        ||', TCM.CLASS_LEVEL '
                        ||', TCM.SUBJECT_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) EXT_ITEM_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),3) MATH_ITEM_CODE '
                        ||', TCM.PAPER_CODE '
                        ||', TCA.CANDIDATE_NO '
                        ||', TCA.scored_ans_mark '
                        ||', TCA.MARKER_SEQ '
                        ||', NVL(TCA.WEIGHT,0) WEIGHT '
                        ||'from '
                        ||'TSA_COMBINED_MASTER TCM '
                        ||', TSA_COMBINED_ANS TCA , TSA_MS_QUESTION TMQ , tsa_ms tm  '
                        ||'WHERE '
                        ||'0 = TCM.REQUEST_ID '
                        ||'AND TCM.COMBINED_MASTER_ID = TCA.COMBINED_MASTER_ID '
                        ||'AND SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) = TMQ.ITEM_CODE '
                        ||'AND EXTRACTVALUE(TMQ.OSM_MS_DTL, ''/ROOT/SHOW_IN_REPORT'') = ''Y'' '
                        ||'AND decode(TCM.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TCM.CLASS_LEVEL) = :sch_level '
                        ||'AND TCM.TSA_YEAR = :TSA_YEAR '
                        ||'AND TCA.INT_TYPE = ''OSM'' '
                        ||'and tm.tsa_year = :TSA_YEAR '
                        ||'and tm.paper_code=tcm.paper_code '
                        ||'and tm.ms_id= tmq.ms_id '
                        ||'and decode(tm.subject_code,''EMATH'',''MATH'',''CMATH'',''MATH'',tm.subject_code) = tcm.subject_code '
                        ||'and tm.class_level = tcm.class_level '
                        ||'AND TCM.CLASS_LEVEL = ''KS1'' '
                        ||') '
                        ||'GROUP BY TSA_YEAR '
                        ||', SCHOOL_ID '
                        ||', decode(CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',CLASS_LEVEL) '
                        ||', SUBJECT_CODE '
                        ||', substr(EXT_ITEM_CODE, instr(EXT_ITEM_CODE, ''T'') +3, 1) '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(PAPER_CODE, 1, 2) || SUBSTR(PAPER_CODE, 4), PAPER_CODE) '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(EXT_ITEM_CODE, 1, 1) || MATH_ITEM_CODE, EXT_ITEM_CODE) '
                        ||', (CANDIDATE_NO||PAPER_CODE) '
                        ||', WEIGHT '
                        ||') '
                        ||'GROUP BY TSA_YEAR, SCHOOL_ID, CLASS_LEVEL, SUBJECT_CODE, DIMENSION, PAPER_CODE, CANDIDATE_NO '
                        ||', WEIGHT '
                        ||'UNION '    --removed ALL' 20100726
                        ||'select TSA_YEAR,SCHOOL_ID,CLASS_LEVEL,SUBJECT,DIMENSION,paper_code,CANDIDATE_NO,avg(TOTAL_MARK)*WEIGHT TOTAL_MARK '
                        ||', WEIGHT '
                        ||'from ( '
                        ||'SELECT '
                        ||'TOUH.TSA_YEAR '
                        ||', (SELECT SCHOOL_ID FROM TEMP_SCHOOL WHERE SCHOOL_CODE = tos.school_code AND STATUS = ''A'') SCHOOL_ID '
                        ||', decode(TOUH.CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',TOUH.CLASS_LEVEL) CLASS_LEVEL '
                        ||', TOUH.SUBJECT '
                        ||', TPM.DIMENSION '
                        ||', TOS.paper_code '
                        ||', TOS.school_code || tos.class_name || tos.class_no CANDIDATE_NO '
                        ||', Nvl(COL1,0)+ Nvl(COL2,0)+ Nvl(COL3,0)+ Nvl(COL4,0)+ decode(COL5,null,0,''A'',0,''B'',0,to_number(COL5)) TOTAL_MARK '
                        ||', NVL(TOS.WEIGHT,0) WEIGHT '
                        ||'FROM '
                        ||'TSA_OSS TOS '
                        ||', tsa_oss_ul_hist TOUH '
                        ||', TSA_PAPER_MASTER TPM '
                        ||'WHERE '
                        ||'tpm.paper_code = tos.paper_code '
                        ||'AND TOS.oss_id=TOUH.oss_id '
                        ||'AND TOUH.TSA_YEAR= :TSA_YEAR '
                        ||'AND decode(TOUH.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TOUH.CLASS_LEVEL) = :sch_level '
                        --||'AND (substr(TOS.PAPER_CODE,3,2) in (''SP'',''SY'') OR substr(TOS.PAPER_CODE,3,2) in (''SG'') OR substr(TOS.PAPER_CODE,2,2) in (''ES'')) '
                        ||'AND TOUH.CLASS_LEVEL = ''KS1'' '
                        ||') group by TSA_YEAR, SCHOOL_ID, CLASS_LEVEL, SUBJECT, DIMENSION, paper_code, CANDIDATE_NO '
                        ||', WEIGHT '
                        ||') GROUP BY '
                        ||'TSA_YEAR '
                        ||', CLASS_LEVEL '
                        ||', SUBJECT_CODE '
                        ||', DIMENSION '
                        ||', PAPER_CODE '
                        ||'ORDER BY '
                        ||'TSA_YEAR '
                        ||', CLASS_LEVEL '
                        ||', SUBJECT_CODE '
                        ||', DIMENSION '
                        ||', PAPER_CODE ';
            EXECUTE IMMEDIATE v_sql_temp USING v_sch_level,r.TSA_YEAR, v_sch_level,r.TSA_YEAR, v_sch_level, r.TSA_YEAR, r.TSA_YEAR, v_sch_level, r.TSA_YEAR, r.TSA_YEAR, r.TSA_YEAR,v_sch_level;
            UTL_FILE.put_line(v_loghandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - All School KS1 End Success');
          END IF;

          IF (v_class_level IS NULL OR v_class_level <> 'P3') THEN
            v_sql_temp := 'INSERT INTO TEMP_AVERAGE '
                        ||'SELECT TSA_YEAR '
                        ||', 0 '
                        ||', CLASS_LEVEL '
                        ||', SUBJECT_CODE '
                        ||', DIMENSION '
                        ||', PAPER_CODE '
                        ||', COUNT(CANDIDATE_NO) NUM_STUDENTS '   --removed DISTINCT 20100726
                        ||', COUNT(CANDIDATE_NO) NUM_STUDENTS '
                        ||', 0 '
                        ||', AVG(total_mark) AVERAGE '
                        ||', sum(total_mark) '
                        ||'FROM '
                        ||'( '
                        ||'SELECT TSA_YEAR, SCHOOL_ID, CLASS_LEVEL, SUBJECT_CODE, DIMENSION, PAPER_CODE, CANDIDATE_NO, SUM(total_mark) TOTAL_MARK '
                        ||'FROM ( '
                        ||'SELECT '
                        ||'TSA_YEAR '
                        ||', SCHOOL_ID '
                        ||', decode(CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',CLASS_LEVEL) CLASS_LEVEL '
                        ||', SUBJECT_CODE SUBJECT_CODE '
                        ||', substr(EXT_ITEM_CODE, instr(EXT_ITEM_CODE, ''T'') +3, 1) DIMENSION '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(PAPER_CODE, 1, 2) || SUBSTR(PAPER_CODE, 4), PAPER_CODE) PAPER_CODE '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(EXT_ITEM_CODE, 1, 1) || MATH_ITEM_CODE, EXT_ITEM_CODE) ITEM_CODE '
                        ||', (CANDIDATE_NO||PAPER_CODE) CANDIDATE_NO '
                        ||', sum(DECODE(scored_ans_mark,''U'',0,''Z'',0,scored_ans_mark))/COUNT(NVL(MARKER_SEQ,1)) total_mark '
                        ||'from ( '
                        ||'select '
                        ||'TCM.TSA_YEAR '
                        ||', TCA.SCHOOL_ID '
                        ||', TCM.CLASS_LEVEL '
                        ||', TCM.SUBJECT_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) EXT_ITEM_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),3) MATH_ITEM_CODE '
                        ||', TCA.CANDIDATE_NO '
                        ||', TCM.PAPER_CODE '
                        ||', TCA.scored_ans_mark '
                        ||', TCA.MARKER_SEQ '
                        ||'FROM '
                        ||'TSA_DATA_CB_HIST TDCH '
                        ||', TSA_COMBINED_MASTER TCM '
                        ||', TSA_COMBINED_ANS TCA '
                        ||'WHERE '
                        ||'TDCH.REQUEST_ID = TCM.REQUEST_ID '
                        ||'AND TCM.COMBINED_MASTER_ID = TCA.COMBINED_MASTER_ID '
                        ||'AND TDCH.ACCEPTANCE = ''A'' '
                        ||'AND TDCH.AUTO_MARKED = ''Y'' '
                        ||'AND decode(TCM.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TCM.CLASS_LEVEL) = :sch_level '
                        ||'AND TCM.TSA_YEAR = :TSA_YEAR '
                        ||'AND TCA.INT_TYPE = ''OMR'' '     -- added for TechnicalSpec-RptBatchFunctSP_V9.5 (6.14.1, 6.14.5)
                        ||'AND TCM.CLASS_LEVEL in (''KS2'',''KS3'') '
                        ||'union all '
                        ||'select '
                        ||'TCM.TSA_YEAR '
                        ||', TCA.SCHOOL_ID '
                        ||', TCM.CLASS_LEVEL '
                        ||', TCM.SUBJECT_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) EXT_ITEM_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),3) MATH_ITEM_CODE '
                        ||', TCA.CANDIDATE_NO '
                        ||', TCM.PAPER_CODE '
                        ||', TCA.scored_ans_mark '
                        ||', TCA.MARKER_SEQ '
                        ||'FROM '
                        ||'TSA_COMBINED_MASTER TCM '
                        ||', TSA_COMBINED_ANS TCA '
                        ||'WHERE '
                        ||'0 = TCM.REQUEST_ID '
                        ||'AND TCM.COMBINED_MASTER_ID = TCA.COMBINED_MASTER_ID '
                        ||'AND decode(TCM.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TCM.CLASS_LEVEL) = :sch_level '
                        ||'AND TCM.TSA_YEAR = :TSA_YEAR '
                        ||'AND TCA.INT_TYPE = ''OMR'' '     -- added for TechnicalSpec-RptBatchFunctSP_V9.5 (6.14.1, 6.14.5)
                        ||'AND TCM.CLASS_LEVEL in (''KS2'',''KS3'') '
                        ||') '
                        ||'GROUP BY TSA_YEAR '
                        ||', SCHOOL_ID '
                        ||', decode(CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',CLASS_LEVEL) '
                        ||', SUBJECT_CODE '
                        ||', substr(EXT_ITEM_CODE, instr(EXT_ITEM_CODE, ''T'') +3, 1) '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(PAPER_CODE, 1, 2) || SUBSTR(PAPER_CODE, 4), PAPER_CODE) '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(EXT_ITEM_CODE, 1, 1) || MATH_ITEM_CODE, EXT_ITEM_CODE) '
                        ||', (CANDIDATE_NO||PAPER_CODE) '
                        ||'UNION ALL '
                        ||'SELECT '
                        ||'TSA_YEAR TSA_YEAR '
                        ||', SCHOOL_ID SCHOOL_ID '
                        ||', decode(CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',CLASS_LEVEL) CLASS_LEVEL '
                        ||', SUBJECT_CODE SUBJECT_CODE '
                        ||', substr(EXT_ITEM_CODE, instr(EXT_ITEM_CODE, ''T'') +3, 1) DIMENSION '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(PAPER_CODE, 1, 2) || SUBSTR(PAPER_CODE, 4), PAPER_CODE) PAPER_CODE '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(EXT_ITEM_CODE, 1, 1) || MATH_ITEM_CODE, EXT_ITEM_CODE) ITEM_CODE '
                        ||', (CANDIDATE_NO||PAPER_CODE) CANDIDATE_NO '
                        ||', sum(DECODE(scored_ans_mark,''U'',0,''Z'',0,scored_ans_mark))/COUNT(NVL(MARKER_SEQ,1)) total_mark '
                        ||'FROM ( '
                        ||'select '
                        ||'TCM.TSA_YEAR '
                        ||', TCA.SCHOOL_ID '
                        ||', TCM.CLASS_LEVEL '
                        ||', TCM.SUBJECT_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) EXT_ITEM_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),3) MATH_ITEM_CODE '
                        ||', TCM.PAPER_CODE '
                        ||', TCA.CANDIDATE_NO '
                        ||', TCA.scored_ans_mark '
                        ||', TCA.MARKER_SEQ '
                        ||'from '
                        ||'TSA_DATA_CB_HIST TDCH '
                        ||', TSA_COMBINED_MASTER TCM '
                        ||', TSA_COMBINED_ANS TCA , TSA_MS_QUESTION TMQ , tsa_ms tm  '
                        ||'WHERE '
                        ||'TDCH.REQUEST_ID = TCM.REQUEST_ID '
                        ||'AND TCM.COMBINED_MASTER_ID = TCA.COMBINED_MASTER_ID '
                        ||'AND SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) = TMQ.ITEM_CODE '
                        ||'AND EXTRACTVALUE(TMQ.OSM_MS_DTL, ''/ROOT/SHOW_IN_REPORT'') = ''Y'' '
                        ||'AND TDCH.ACCEPTANCE = ''A'' '
                        ||'AND TDCH.AUTO_MARKED = ''Y'' '
                        ||'AND decode(TCM.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TCM.CLASS_LEVEL) = :sch_level '
                        ||'AND TCM.TSA_YEAR = :TSA_YEAR '
                        ||'AND TCA.INT_TYPE = ''OSM'' '
                        ||'and tm.tsa_year = :TSA_YEAR '
                        ||'and tm.paper_code=tcm.paper_code '
                        ||'and tm.ms_id= tmq.ms_id '
                        ||'and decode(tm.subject_code,''EMATH'',''MATH'',''CMATH'',''MATH'',tm.subject_code) = tcm.subject_code '
                        ||'and tm.class_level = tcm.class_level '
                        ||'AND TCM.CLASS_LEVEL in (''KS2'',''KS3'') '
                        ||'union all '
                        ||'select '
                        ||'TCM.TSA_YEAR '
                        ||', TCA.SCHOOL_ID '
                        ||', TCM.CLASS_LEVEL '
                        ||', TCM.SUBJECT_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) EXT_ITEM_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),3) MATH_ITEM_CODE '
                        ||', TCM.PAPER_CODE '
                        ||', TCA.CANDIDATE_NO '
                        ||', TCA.scored_ans_mark '
                        ||', TCA.MARKER_SEQ '
                        ||'from '
                        ||'TSA_COMBINED_MASTER TCM '
                        ||', TSA_COMBINED_ANS TCA , TSA_MS_QUESTION TMQ , tsa_ms tm  '
                        ||'WHERE '
                        ||'0 = TCM.REQUEST_ID '
                        ||'AND TCM.COMBINED_MASTER_ID = TCA.COMBINED_MASTER_ID '
                        ||'AND SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) = TMQ.ITEM_CODE '
                        ||'AND EXTRACTVALUE(TMQ.OSM_MS_DTL, ''/ROOT/SHOW_IN_REPORT'') = ''Y'' '
                        ||'AND decode(TCM.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TCM.CLASS_LEVEL) = :sch_level '
                        ||'AND TCM.TSA_YEAR = :TSA_YEAR '
                        ||'AND TCA.INT_TYPE = ''OSM'' '
                        ||'and tm.tsa_year = :TSA_YEAR '
                        ||'and tm.paper_code=tcm.paper_code '
                        ||'and tm.ms_id= tmq.ms_id '
                        ||'and decode(tm.subject_code,''EMATH'',''MATH'',''CMATH'',''MATH'',tm.subject_code) = tcm.subject_code '
                        ||'and tm.class_level = tcm.class_level '
                        ||'AND TCM.CLASS_LEVEL in (''KS2'',''KS3'') '
                        ||') '
                        ||'GROUP BY TSA_YEAR '
                        ||', SCHOOL_ID '
                        ||', decode(CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',CLASS_LEVEL) '
                        ||', SUBJECT_CODE '
                        ||', substr(EXT_ITEM_CODE, instr(EXT_ITEM_CODE, ''T'') +3, 1) '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(PAPER_CODE, 1, 2) || SUBSTR(PAPER_CODE, 4), PAPER_CODE) '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(EXT_ITEM_CODE, 1, 1) || MATH_ITEM_CODE, EXT_ITEM_CODE) '
                        ||', (CANDIDATE_NO||PAPER_CODE) '
                        ||') '
                        ||'GROUP BY TSA_YEAR, SCHOOL_ID, CLASS_LEVEL, SUBJECT_CODE, DIMENSION, PAPER_CODE, CANDIDATE_NO '
                        ||'UNION '    --removed ALL' 20100726
                        ||'select TSA_YEAR,SCHOOL_ID,CLASS_LEVEL,SUBJECT,DIMENSION,paper_code,CANDIDATE_NO,avg(TOTAL_MARK) TOTAL_MARK '
                        ||'from ( '
                        ||'SELECT '
                        ||'TOUH.TSA_YEAR '
                        ||', (SELECT SCHOOL_ID FROM TEMP_SCHOOL WHERE SCHOOL_CODE = tos.school_code AND STATUS = ''A'') SCHOOL_ID '
                        ||', decode(TOUH.CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',TOUH.CLASS_LEVEL) CLASS_LEVEL '
                        ||', TOUH.SUBJECT '
                        ||', TPM.DIMENSION '
                        ||', TOS.paper_code '
                        ||', TOS.school_code || tos.class_name || tos.class_no CANDIDATE_NO '
                        ||', Nvl(COL1,0)+ Nvl(COL2,0)+ Nvl(COL3,0)+ Nvl(COL4,0)+ decode(COL5,null,0,''A'',0,''B'',0,to_number(COL5)) TOTAL_MARK '
                        ||'FROM '
                        ||'TSA_OSS TOS '
                        ||', tsa_oss_ul_hist TOUH '
                        ||', TSA_PAPER_MASTER TPM '
                        ||'WHERE '
                        ||'tpm.paper_code = tos.paper_code '
                        ||'AND TOS.oss_id=TOUH.oss_id '
                        ||'AND TOUH.TSA_YEAR= :TSA_YEAR '
                        ||'AND decode(TOUH.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TOUH.CLASS_LEVEL) = :sch_level '
                        ||'AND TOUH.CLASS_LEVEL in (''KS2'',''KS3'') '
                        ||') group by TSA_YEAR, SCHOOL_ID, CLASS_LEVEL, SUBJECT, DIMENSION, paper_code, CANDIDATE_NO '
                        ||') GROUP BY '
                        ||'TSA_YEAR '
                        ||', CLASS_LEVEL '
                        ||', SUBJECT_CODE '
                        ||', DIMENSION '
                        ||', PAPER_CODE '
                        ||'ORDER BY '
                        ||'TSA_YEAR '
                        ||', CLASS_LEVEL '
                        ||', SUBJECT_CODE '
                        ||', DIMENSION '
                        ||', PAPER_CODE ';
            EXECUTE IMMEDIATE v_sql_temp USING v_sch_level,r.TSA_YEAR, v_sch_level,r.TSA_YEAR, v_sch_level, r.TSA_YEAR, r.TSA_YEAR, v_sch_level, r.TSA_YEAR, r.TSA_YEAR, r.TSA_YEAR,v_sch_level;
            UTL_FILE.put_line(v_loghandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - All School KS2,KS3 End Success');
          END IF;

          v_sql_temp := 'UPDATE TEMP_AVERAGE A SET  A.MAXIMUM_SCORE_A = '
                      ||'NVL((SELECT FULL_MARK FROM ( '
                      ||'SELECT TSA_YEAR, CLASS_LEVEL, SUBJECT_CODE, DIMENSION, PAPER_CODE, SUM (FULL_MARK) FULL_MARK FROM ( '
                      ||'SELECT DISTINCT MS.TSA_YEAR '
                      ||'  , decode(MS.CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',MS.CLASS_LEVEL) CLASS_LEVEL '
                      ||'  , DECODE(MS.SUBJECT_CODE, ''EMATH'', ''MATH'', ''CMATH'',''MATH'',MS.SUBJECT_CODE ) SUBJECT_CODE '
                      ||'  , substr(TMQ.ITEM_CODE, instr(TMQ.ITEM_CODE, ''T'') +3, 1) DIMENSION '
                      ||'  , (CASE WHEN MS.SUBJECT_CODE IN (''CMATH'',''EMATH'') THEN (SUBSTR(MS.PAPER_CODE, 1, 2) || SUBSTR(MS.PAPER_CODE, 4)) ELSE MS.PAPER_CODE END) PAPER_CODE '
                      ||'  , (CASE WHEN MS.SUBJECT_CODE IN (''CMATH'',''EMATH'') THEN SUBSTR(TMQ.ITEM_CODE,1,1)||SUBSTR(TMQ.ITEM_CODE,3) ELSE TMQ.ITEM_CODE END) ITEM_CODE '
                      ||'  , TO_NUMBER(TMQ.FULL_MARK) FULL_MARK '
                      ||'FROM TSA_MS MS '
                      ||', TSA_MS_QUESTION TMQ '
                      ||'WHERE MS.MS_ID = TMQ.MS_ID '
                      ||'AND TMQ.FULL_MARK <> ''NA'' '
                      ||'AND MS.TSA_YEAR= :1 '
                      ||'AND (((MS.CLASS_LEVEL = ''KS1'' or MS.CLASS_LEVEL = ''KS2'') AND ''P'' = :2) OR (MS.CLASS_LEVEL = ''KS3'' AND ''S'' = :3)) '
                      ||') '
                      ||'GROUP BY '
                      ||'  TSA_YEAR, CLASS_LEVEL, SUBJECT_CODE, DIMENSION, PAPER_CODE '
                      ||'UNION ALL '
                      ||'SELECT '
                      ||'TMO.TSA_YEAR '
                      ||', DECODE(TMO.CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',TMO.CLASS_LEVEL) CLASS_LEVEL '
                      ||', TMO.SUBJECT_CODE '
                      ||', TPM.DIMENSION '
                      ||', TMO.PAPER_CODE '
                      ||', SUM (TMOC.FULL_MARK) FULL_MARK '
                      ||'FROM '
                      ||'TSA_MS_ORAL TMO '
                      ||', TSA_MS_ORAL_CRIT TMOC '
                      ||', TSA_PAPER_MASTER TPM '
                      ||'WHERE '
                      ||'TPM.PAPER_CODE = TMO.PAPER_CODE '
                      ||'AND TMO.MS_ORAL_ID = TMOC.MS_ORAL_ID '
                      ||'AND TMO.TSA_YEAR= :4 '
                      ||'AND (((TMO.CLASS_LEVEL = ''KS1'' or TMO.CLASS_LEVEL = ''KS2'') AND ''P'' = :5) OR (TMO.CLASS_LEVEL = ''KS3'' AND ''S'' = :6)) '
                      ||'GROUP BY '
                      ||'TMO.TSA_YEAR '
                      ||', TMO.CLASS_LEVEL '
                      ||', DECODE(TMO.CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',TMO.CLASS_LEVEL) '
                      ||', TMO.SUBJECT_CODE '
                      ||', TPM.DIMENSION '
                      ||', TMO.PAPER_CODE '
                      ||') B '
                      ||'WHERE A.TSA_YEAR = B.TSA_YEAR '
                      ||'AND A.CLASS_LEVEL = B.CLASS_LEVEL '
                      ||'AND A.SUBJECT_CODE = B.SUBJECT_CODE '
                      ||'AND A.DIMENSION = B.DIMENSION '
                      ||'AND A.PAPER_CODE = B.PAPER_CODE ),0) ';
          EXECUTE IMMEDIATE v_sql_temp USING r.TSA_YEAR,v_sch_level,v_sch_level, r.TSA_YEAR,v_sch_level,v_sch_level;

          v_sql_temp := 'INSERT INTO TEMP_AVERAGE '
                      ||'select tsa_year, school_id, class_level, subject_code,  ''Z'', paper_code, max(number_student), max(number_student), sum(maximum_score_a), sum(school_avg_b), sum(school_avg_b) '
                      --||'select tsa_year, school_id, class_level, subject_code,  ''Z'', paper_code, max(number_student), sum(maximum_score_a), sum(school_avg_b), sum(school_avg_b) '
                      ||'from TEMP_AVERAGE '
                      ||'where subject_code = ''MATH'' '
                      ||'AND SCHOOL_ID = 0 '
                      ||'group by tsa_year, school_id, class_level, subject_code, paper_code ';
          EXECUTE IMMEDIATE v_sql_temp;

          Delete from TSA_RPT_SCH_SP
          Where tsa_year = r.TSA_YEAR
          And School_id = 0
          --AND (('P' = v_sch_level AND (CLASS_LEVEL = 'P3' OR CLASS_LEVEL = 'P6')) OR ('S' = v_sch_level AND CLASS_LEVEL = 'S3'));
          AND (('P' = v_sch_level AND ((v_class_level IS NULL AND CLASS_LEVEL IN ('P3','P6')) OR (v_class_level IS NOT NULL AND CLASS_LEVEL = v_class_level))) OR ('S' = v_sch_level AND CLASS_LEVEL = 'S3'));

          V_DATE := TRUNC(SYSDATE,'MI');
          /*v_sql_temp := 'INSERT INTO TSA_RPT_SCH_SP(TSA_YEAR, SCHOOL_ID, CLASS_LEVEL, SUBJECT_CODE, DIMENSION, SUB_PAPER_CODE, NUMBER_OF_STUDENT, SCH_MAX_SCORE, SCH_AVG_SCORE, TOTAL_SCORE, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE, LAST_UPDATED_BY) '
          ||'SELECT A.*, :1, :2, :3, :4 '*/
          v_sql_temp := 'INSERT INTO TSA_RPT_SCH_SP(TSA_YEAR, SCHOOL_ID, CLASS_LEVEL, SUBJECT_CODE, DIMENSION, SUB_PAPER_CODE, NUMBER_OF_STUDENT,RATED_NUM_OF_STUDENT, SCH_MAX_SCORE, SCH_AVG_SCORE, TOTAL_SCORE, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE, LAST_UPDATED_BY) '
                      ||'SELECT TSA_YEAR,SCHOOL_ID,CLASS_LEVEL,SUBJECT_CODE,DIMENSION,PAPER_CODE,NUMBER_STUDENT,WEIGHT_NUM_OF_STUDENT,MAXIMUM_SCORE_A,SCHOOL_AVG_B,TOTAL_SCORE, :1, :2, :3, :4 '
                      ||'FROM TEMP_AVERAGE A '
                      ||'WHERE A.SCHOOL_ID = 0 '
                      --||'AND ((''P'' = :5 AND (CLASS_LEVEL = ''P3'' OR CLASS_LEVEL = ''P6''))  OR (''S'' = :6 AND CLASS_LEVEL = ''S3'')) ';
                      ||'AND ((''P'' = :5 AND ((:6 IS NULL AND CLASS_LEVEL IN (''P3'',''P6'')) OR (:7 IS NOT NULL AND CLASS_LEVEL = :8))) OR (''S'' = :9 AND CLASS_LEVEL = ''S3'')) ';
          EXECUTE IMMEDIATE v_sql_temp USING V_DATE,r.CREATED_BY,V_DATE,r.CREATED_BY,v_sch_level,v_class_level,v_class_level,v_class_level,v_sch_level;

          COMMIT;
        END IF;

        v_sql_temp := 'SELECT varchar_number(B.SCHOOL_ID, B.SCHOOL_CODE) FROM TEMP_SCHOOL B WHERE B.SCHOOL_LEVEL = :1 and B.status = ''A'' and B.tsa_flag = ''Y'' '
                    ||' AND NOT EXISTS (SELECT 1 FROM TSA_RPT_SCH A WHERE A.SCHOOL_ID = B.SCHOOL_ID and A.TSA_YEAR = :2 ) ';
        IF r.SCHOOL_CODE IS NOT NULL THEN
          v_sql_temp := v_sql_temp || ' AND B.SCHOOL_CODE = ''' || r.SCHOOL_CODE || '''';
        END IF;
      /*LOOP
          FETCH  CUR_ASS_COUNT  INTO  v_sch_id, v_sch_code;
          EXIT WHEN CUR_ASS_COUNT%NOTFOUND;
      */
        EXECUTE IMMEDIATE v_sql_temp bulk collect into ret USING v_sch_level, r.TSA_YEAR;
        for rec in (select * from table(cast(ret as t_varchar_number))) loop
        BEGIN

          UTL_FILE.put_line(v_exchandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - Begin to process school: ' || rec.v_sch_code);
          UTL_FILE.put_line(v_exchandle,'  ');

          EXECUTE IMMEDIATE 'DELETE FROM TEMP_PERCENTAGE WHERE SCHOOL_ID <> 0 ';
          EXECUTE IMMEDIATE 'DELETE FROM TEMP_AVERAGE WHERE SCHOOL_ID <> 0 ';

          v_sql_temp := 'INSERT INTO TEMP_PERCENTAGE '
                      ||'SELECT '
                      ||'TLUH.TSA_YEAR '
                      ||', TL.SYS_SCHOOL_ID '
                      ||', TLUH.CLASS_LEVEL '
                      ||', TLUH.SUBJECT '
                      ||', COUNT(1) COUNTERA, 0 '
                      ||'FROM TSA_LOGIT_UL_HIST TLUH, TSA_LOGIT TL '
                      ||'WHERE TLUH.REQUEST_ID = TL.REQUEST_ID '
                      --||'AND ((''P'' = :1 AND (CLASS_LEVEL = ''P3'' OR CLASS_LEVEL = ''P6'')) OR (''S'' = :2 AND CLASS_LEVEL = ''S3'')) '
                      ||'AND ((''P'' = :1 AND ((:2 IS NULL AND CLASS_LEVEL IN (''P3'',''P6'')) OR (:3 IS NOT NULL AND CLASS_LEVEL = :4))) OR (''S'' = :5 AND CLASS_LEVEL = ''S3'')) '
                      ||'AND TL.SYS_SCHOOL_CODE= :6 '
                      ||'AND TLUH.TSA_YEAR = :7 '
                      ||'GROUP BY TLUH.TSA_YEAR, TL.SYS_SCHOOL_ID, TLUH.CLASS_LEVEL, TLUH.SUBJECT, TL.SYS_SCHOOL_ID ';
          EXECUTE IMMEDIATE v_sql_temp USING v_sch_level, v_class_level, v_class_level, v_class_level, v_sch_level, rec.v_sch_code, r.TSA_YEAR;

          v_sql_temp := 'UPDATE TEMP_PERCENTAGE A SET A.NUMBER_STUDENT_B = '
                      ||'NVL((SELECT nvl(COUNTERB,0) FROM ( '
                      ||'SELECT '
                      ||'TLUH.TSA_YEAR '
                      ||', TLUH.CLASS_LEVEL '
                      ||', TLUH.SUBJECT '
                      ||', TL.SYS_SCHOOL_ID '
                      ||', COUNT(1) COUNTERB '
                      ||'FROM TSA_LOGIT_UL_HIST TLUH, TSA_LOGIT TL, TSA_BENCHMARK TB '
                      ||'WHERE TLUH.REQUEST_ID = TL.REQUEST_ID '
                      ||'AND TB.TSA_YEAR = TLUH.TSA_YEAR '
                      ||'AND '
                      ||'( '
                      ||'  (TLUH.CLASS_LEVEL = ''P3'' AND '
                      ||'    ( '
                      ||'      (TLUH.SUBJECT=''CHI'' AND TL.LOGIT_VALUE >=TB.P3CHI ) '
                      ||'      OR '
                      ||'      (TLUH.SUBJECT=''ENG'' AND TL.LOGIT_VALUE >=TB.P3ENG ) '
                      ||'      OR '
                      ||'      (TLUH.SUBJECT=''MATH'' AND TL.LOGIT_VALUE >=TB.P3MATH ) '
                      ||'    ) '
                      ||'  ) OR '
                      ||'  (TLUH.CLASS_LEVEL = ''P6'' AND '
                      ||'    ( '
                      ||'      (TLUH.SUBJECT=''CHI'' AND TL.LOGIT_VALUE >=TB.P6CHI ) '
                      ||'      OR '
                      ||'      (TLUH.SUBJECT=''ENG'' AND TL.LOGIT_VALUE >=TB.P6ENG ) '
                      ||'      OR '
                      ||'      (TLUH.SUBJECT=''MATH'' AND TL.LOGIT_VALUE >=TB.P6MATH ) '
                      ||'    ) '
                      ||'  )OR '
                      ||'  (TLUH.CLASS_LEVEL = ''S3'' AND '
                      ||'    ( '
                      ||'      (TLUH.SUBJECT=''CHI'' AND TL.LOGIT_VALUE >=TB.S3CHI ) '
                      ||'      OR '
                      ||'      (TLUH.SUBJECT=''ENG'' AND TL.LOGIT_VALUE >=TB.S3ENG ) '
                      ||'      OR '
                      ||'      (TLUH.SUBJECT=''MATH'' AND TL.LOGIT_VALUE >=TB.S3MATH ) '
                      ||'    ) '
                      ||'  ) '
                      ||') '
                      ||'AND TB.TSA_YEAR = :1 '
                      ||'AND TL.SYS_SCHOOL_CODE = :2 '
                      ||'AND ((''P'' = :3 AND (CLASS_LEVEL = ''P3'' OR CLASS_LEVEL = ''P6'')) OR (''S'' = :4 AND CLASS_LEVEL = ''S3'')) '
                      --     ||'AND TL.SYS_SCHOOL_CODE= :5 '
                      ||'GROUP BY TLUH.TSA_YEAR, TLUH.CLASS_LEVEL, TLUH.SUBJECT, TL.SYS_SCHOOL_ID '
                      ||') B '
                      ||'WHERE A.TSA_YEAR = A.TSA_YEAR '
                      ||'AND A.CLASS_LEVEL = B.CLASS_LEVEL '
                      ||'AND A.SUBJECT_CODE = B.SUBJECT '
                      ||'AND A.SCHOOL_ID = B.SYS_SCHOOL_ID ),0) ';
          EXECUTE IMMEDIATE v_sql_temp using r.TSA_YEAR, rec.v_sch_code, v_sch_level, v_sch_level /* , rec.v_sch_code */;

          IF (v_sch_level = 'P' AND (v_class_level IS NULL OR v_class_level = 'P3')) THEN
            v_sql_temp := 'INSERT INTO TEMP_AVERAGE '
                        ||'SELECT TSA_YEAR '
                        ||', SCHOOL_ID '
                        ||', CLASS_LEVEL '
                        ||', SUBJECT_CODE '
                        ||', DIMENSION '
                        ||', PAPER_CODE '
                        ||', COUNT(CANDIDATE_NO) NUM_STUDENTS '  --removed DISTINCT 20100726
                        ||', sum(WEIGHT) WEIGHT_NUM_STUDENTS '
                        ||', 0 '
                        --||', AVG(total_mark) AVERAGE '
                        ||', decode(sum(WEIGHT),0,0,sum(total_mark) / sum(WEIGHT)) AVERAGE '
                        ||', sum(total_mark) '
                        ||'FROM '
                        ||'( '
                        ||'SELECT TSA_YEAR, SCHOOL_ID, CLASS_LEVEL, SUBJECT_CODE, DIMENSION, PAPER_CODE, CANDIDATE_NO, SUM(total_mark)*WEIGHT TOTAL_MARK '
                        ||',WEIGHT '
                        ||'FROM ( '
                        ||'SELECT '
                        ||'TSA_YEAR TSA_YEAR '
                        ||', SCHOOL_ID SCHOOL_ID '
                        ||', decode(CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',CLASS_LEVEL) CLASS_LEVEL '
                        ||', SUBJECT_CODE SUBJECT_CODE '
                        ||', substr(EXT_ITEM_CODE, instr(EXT_ITEM_CODE, ''T'') +3, 1) DIMENSION '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(PAPER_CODE, 1, 2) || SUBSTR(PAPER_CODE, 4), PAPER_CODE) PAPER_CODE '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(EXT_ITEM_CODE, 1, 1) || MATH_ITEM_CODE, EXT_ITEM_CODE) ITEM_CODE '
                        ||', (CANDIDATE_NO||PAPER_CODE) CANDIDATE_NO '
                        ||', sum(DECODE(scored_ans_mark,''U'',0,''Z'',0,scored_ans_mark))/COUNT(NVL(MARKER_SEQ,1)) total_mark '
                        ||',WEIGHT '
                        ||'FROM ( '
                        ||'select '
                        ||'TCM.TSA_YEAR '
                        ||', TCA.SCHOOL_ID '
                        ||', TCM.CLASS_LEVEL '
                        ||', TCM.SUBJECT_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) EXT_ITEM_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),3) MATH_ITEM_CODE '
                        ||', TCM.PAPER_CODE '
                        ||', TCA.CANDIDATE_NO '
                        ||', TCA.scored_ans_mark '
                        ||', TCA.MARKER_SEQ '
                        ||', NVL(TCA.WEIGHT,0) WEIGHT '
                        ||'from '
                        ||'TSA_DATA_CB_HIST TDCH '
                        ||', TSA_COMBINED_MASTER TCM '
                        ||', TSA_COMBINED_ANS TCA '
                        ||'WHERE '
                        ||'TDCH.REQUEST_ID = TCM.REQUEST_ID '
                        ||'AND TCM.COMBINED_MASTER_ID = TCA.COMBINED_MASTER_ID '
                        ||'AND TDCH.ACCEPTANCE = ''A'' '
                        ||'AND TDCH.AUTO_MARKED = ''Y'' '
                        ||'AND decode(TCM.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TCM.CLASS_LEVEL) = :sch_level '
                        ||'AND TCA.INT_TYPE = ''OMR'' '   -- added for TechnicalSpec-RptBatchFunctSP_V9.5 ( 6.15.1, 6.15.5)
                        ||'AND TCM.TSA_YEAR = :TSA_YEAR '
                        ||'AND TCA.SCHOOL_ID = :sch_id '
                        ||'AND TCM.SUB_DIMENSION = ''CA'' '
                        ||'AND TCM.CLASS_LEVEL = ''KS1'' '
                        ||'union all '
                        ||'select '
                        ||'TCM.TSA_YEAR '
                        ||', TCA.SCHOOL_ID '
                        ||', TCM.CLASS_LEVEL '
                        ||', TCM.SUBJECT_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) EXT_ITEM_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),3) MATH_ITEM_CODE '
                        ||', TCM.PAPER_CODE '
                        ||', TCA.CANDIDATE_NO '
                        ||', TCA.scored_ans_mark '
                        ||', TCA.MARKER_SEQ '
                        ||', NVL(TCA.WEIGHT,0) WEIGHT '
                        ||'from '
                        ||'TSA_COMBINED_MASTER TCM '
                        ||', TSA_COMBINED_ANS TCA '
                        ||'WHERE '
                        ||'0 = TCM.REQUEST_ID '
                        ||'AND TCM.COMBINED_MASTER_ID = TCA.COMBINED_MASTER_ID '
                        ||'AND decode(TCM.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TCM.CLASS_LEVEL) = :sch_level '
                        ||'AND TCA.INT_TYPE = ''OMR'' '   -- added for TechnicalSpec-RptBatchFunctSP_V9.5 ( 6.15.1, 6.15.5)
                        ||'AND TCM.TSA_YEAR = :TSA_YEAR '
                        ||'AND TCA.SCHOOL_ID = :sch_id '
                        ||'AND TCM.SUB_DIMENSION = ''CA'' '
                        ||'AND TCM.CLASS_LEVEL = ''KS1'' '
                        ||') '
                        ||'GROUP BY TSA_YEAR, SCHOOL_ID, decode(CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',CLASS_LEVEL), SUBJECT_CODE, substr(EXT_ITEM_CODE, instr(EXT_ITEM_CODE, ''T'') +3, 1), DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(PAPER_CODE, 1, 2) || SUBSTR(PAPER_CODE, 4), PAPER_CODE), DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(EXT_ITEM_CODE, 1, 1) || MATH_ITEM_CODE, EXT_ITEM_CODE), (CANDIDATE_NO||PAPER_CODE) '
                        ||',WEIGHT '
                        ||'UNION ALL '
                        ||'SELECT '
                        ||'TSA_YEAR TSA_YEAR '
                        ||', SCHOOL_ID SCHOOL_ID '
                        ||', decode(CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',CLASS_LEVEL) CLASS_LEVEL '
                        ||', SUBJECT_CODE SUBJECT_CODE '
                        ||', substr(EXT_ITEM_CODE, instr(EXT_ITEM_CODE, ''T'') +3, 1) DIMENSION '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(PAPER_CODE, 1, 2) || SUBSTR(PAPER_CODE, 4), PAPER_CODE) PAPER_CODE '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(EXT_ITEM_CODE, 1, 1) || MATH_ITEM_CODE, EXT_ITEM_CODE) ITEM_CODE '
                        ||', (CANDIDATE_NO||PAPER_CODE) CANDIDATE_NO '
                        ||', sum(DECODE(scored_ans_mark,''U'',0,''Z'',0,scored_ans_mark))/COUNT(NVL(MARKER_SEQ,1)) total_mark '
                        ||',WEIGHT '
                        ||'FROM ( '
                        ||'select '
                        ||'TCM.TSA_YEAR '
                        ||', TCA.SCHOOL_ID '
                        ||', TCM.CLASS_LEVEL '
                        ||', TCM.SUBJECT_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) EXT_ITEM_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),3) MATH_ITEM_CODE '
                        ||', TCM.PAPER_CODE '
                        ||', TCA.CANDIDATE_NO '
                        ||', TCA.scored_ans_mark '
                        ||', TCA.MARKER_SEQ '
                        ||', NVL(TCA.WEIGHT,0) WEIGHT '
                        ||'from '
                        ||'TSA_DATA_CB_HIST TDCH '
                        ||', TSA_COMBINED_MASTER TCM '
                        ||', TSA_COMBINED_ANS TCA , TSA_MS_QUESTION TMQ , tsa_ms tm '
                        ||'WHERE '
                        ||'TDCH.REQUEST_ID = TCM.REQUEST_ID '
                        ||'AND TCM.COMBINED_MASTER_ID = TCA.COMBINED_MASTER_ID '
                        ||'AND SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) = TMQ.ITEM_CODE '
                        ||'AND EXTRACTVALUE(TMQ.OSM_MS_DTL, ''/ROOT/SHOW_IN_REPORT'') = ''Y'' '
                        ||'AND TDCH.ACCEPTANCE = ''A'' '
                        ||'AND TDCH.AUTO_MARKED = ''Y'' '
                        ||'AND decode(TCM.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TCM.CLASS_LEVEL) = :sch_level '
                        ||'AND TCA.INT_TYPE = ''OSM'' '
                        ||'AND TCM.TSA_YEAR = :TSA_YEAR '
                        ||'AND TCA.SCHOOL_ID = :sch_id '
                        ||'and tm.tsa_year = :TSA_YEAR '
                        ||'and tm.paper_code=tcm.paper_code '
                        ||'and tm.ms_id= tmq.ms_id '
                        ||'and decode(tm.subject_code,''EMATH'',''MATH'',''CMATH'',''MATH'',tm.subject_code) = tcm.subject_code '
                        ||'and tm.class_level = tcm.class_level '
                        ||'AND TCM.SUB_DIMENSION = ''CA'' '
                        ||'AND TCM.CLASS_LEVEL = ''KS1'' '
                        ||'union all '
                        ||'select '
                        ||'TCM.TSA_YEAR '
                        ||', TCA.SCHOOL_ID '
                        ||', TCM.CLASS_LEVEL '
                        ||', TCM.SUBJECT_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) EXT_ITEM_CODE '
                        ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),3) MATH_ITEM_CODE '
                        ||', TCM.PAPER_CODE '
                        ||', TCA.CANDIDATE_NO '
                        ||', TCA.scored_ans_mark '
                        ||', TCA.MARKER_SEQ '
                        ||', NVL(TCA.WEIGHT,0) WEIGHT '
                        ||'from '
                        ||'TSA_COMBINED_MASTER TCM '
                        ||', TSA_COMBINED_ANS TCA , TSA_MS_QUESTION TMQ , tsa_ms tm '
                        ||'WHERE '
                        ||'0 = TCM.REQUEST_ID '
                        ||'AND TCM.COMBINED_MASTER_ID = TCA.COMBINED_MASTER_ID '
                        ||'AND SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) = TMQ.ITEM_CODE '
                        ||'AND EXTRACTVALUE(TMQ.OSM_MS_DTL, ''/ROOT/SHOW_IN_REPORT'') = ''Y'' '
                        ||'AND decode(TCM.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TCM.CLASS_LEVEL) = :sch_level '
                        ||'AND TCA.INT_TYPE = ''OSM'' '
                        ||'AND TCM.TSA_YEAR = :TSA_YEAR '
                        ||'AND TCA.SCHOOL_ID = :sch_id '
                        ||'and tm.tsa_year = :TSA_YEAR '
                        ||'and tm.paper_code=tcm.paper_code '
                        ||'and tm.ms_id= tmq.ms_id '
                        ||'and decode(tm.subject_code,''EMATH'',''MATH'',''CMATH'',''MATH'',tm.subject_code) = tcm.subject_code '
                        ||'and tm.class_level = tcm.class_level '
                        ||'AND TCM.SUB_DIMENSION = ''CA'' '
                        ||'AND TCM.CLASS_LEVEL = ''KS1'' '
                        ||') '
                        ||'GROUP BY TSA_YEAR '
                        ||', SCHOOL_ID '
                        ||', decode(CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',CLASS_LEVEL) '
                        ||', SUBJECT_CODE '
                        ||', substr(EXT_ITEM_CODE, instr(EXT_ITEM_CODE, ''T'') +3, 1) '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(PAPER_CODE, 1, 2) || SUBSTR(PAPER_CODE, 4), PAPER_CODE) '
                        ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(EXT_ITEM_CODE, 1, 1) || MATH_ITEM_CODE, EXT_ITEM_CODE) '
                        ||', (CANDIDATE_NO||PAPER_CODE) '
                        ||', WEIGHT '
                        ||') '
                        ||'GROUP BY TSA_YEAR, SCHOOL_ID, CLASS_LEVEL, SUBJECT_CODE, DIMENSION, PAPER_CODE, CANDIDATE_NO '
                        ||',WEIGHT '
                        ||'UNION '   --removed ALL' 20100726
                        ||'select TSA_YEAR,SCHOOL_ID,CLASS_LEVEL,SUBJECT,DIMENSION,paper_code,CANDIDATE_NO,avg(TOTAL_MARK)*WEIGHT TOTAL_MARK '
                        ||', WEIGHT '
                        ||'from ( '
                        ||'SELECT '
                        ||'TOUH.TSA_YEAR '
                        ||', (SELECT SCHOOL_ID FROM TEMP_SCHOOL WHERE SCHOOL_CODE = tos.school_code AND STATUS = ''A'') SCHOOL_ID '
                        ||', decode(TOUH.CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',TOUH.CLASS_LEVEL) CLASS_LEVEL '
                        ||', TOUH.SUBJECT '
                        ||', TPM.DIMENSION '
                        ||', TOS.paper_code '
                        ||', TOS.school_code || tos.class_name || tos.class_no CANDIDATE_NO '
                        ||', Nvl(COL1,0)+ Nvl(COL2,0)+ Nvl(COL3,0)+ Nvl(COL4,0)+ decode(COL5,null,0,''A'',0,''B'',0,to_number(COL5)) TOTAL_MARK '
                        ||', NVL(TOS.WEIGHT,0) WEIGHT '
                        ||'FROM '
                        ||'TSA_OSS TOS '
                        ||', tsa_oss_ul_hist TOUH '
                        ||', TSA_PAPER_MASTER TPM '
                        ||'WHERE '
                        ||'tpm.paper_code = tos.paper_code '
                        ||'AND TOS.oss_id=TOUH.oss_id '
                        ||'AND TOUH.TSA_YEAR= :TSA_YEAR '
                        ||'AND TOS.SCHOOL_CODE = :sch_code '
                        ||'AND decode(TOUH.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TOUH.CLASS_LEVEL) = :sch_level '
                        --||'AND (substr(TOS.PAPER_CODE,3,2) in (''SP'',''SY'') OR substr(TOS.PAPER_CODE,3,2) in (''SG'') OR substr(TOS.PAPER_CODE,2,2) in (''ES'')) '
                        ||'AND TOUH.CLASS_LEVEL = ''KS1'' '
                        ||') group by TSA_YEAR, SCHOOL_ID, CLASS_LEVEL, SUBJECT, DIMENSION, paper_code, CANDIDATE_NO '
                        ||', WEIGHT '
                        ||') GROUP BY '
                        ||'TSA_YEAR '
                        ||', SCHOOL_ID '
                        ||', CLASS_LEVEL '
                        ||', SUBJECT_CODE '
                        ||', DIMENSION '
                        ||', PAPER_CODE '
                        ||'ORDER BY '
                        ||'TSA_YEAR '
                        ||', SCHOOL_ID '
                        ||', CLASS_LEVEL '
                        ||', SUBJECT_CODE '
                        ||', DIMENSION '
                        ||', PAPER_CODE ';
            EXECUTE IMMEDIATE v_sql_temp USING v_sch_level,r.TSA_YEAR, rec.v_sch_id, v_sch_level,r.TSA_YEAR, rec.v_sch_id ,v_sch_level,r.TSA_YEAR, rec.v_sch_id ,r.TSA_YEAR,v_sch_level,r.TSA_YEAR, rec.v_sch_id ,r.TSA_YEAR, r.TSA_YEAR, rec.v_sch_code,v_sch_level;
            UTL_FILE.put_line(v_loghandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - ' || rec.v_sch_code || ' KS1 CA End Success');
          END IF;

          v_sql_temp := 'INSERT INTO TEMP_AVERAGE '
                      ||'SELECT TSA_YEAR '
                      ||', SCHOOL_ID '
                      ||', CLASS_LEVEL '
                      ||', SUBJECT_CODE '
                      ||', DIMENSION '
                      ||', PAPER_CODE '
                      ||', COUNT(CANDIDATE_NO) NUM_STUDENTS '  --removed DISTINCT 20100726
                      ||', COUNT(CANDIDATE_NO) NUM_STUDENTS '
                      ||', 0 '
                      ||', AVG(total_mark) AVERAGE '
                      ||', sum(total_mark) '
                      ||'FROM '
                      ||'( '
                      ||'SELECT TSA_YEAR, SCHOOL_ID, CLASS_LEVEL, SUBJECT_CODE, DIMENSION, PAPER_CODE, CANDIDATE_NO, SUM(total_mark) TOTAL_MARK '
                      ||'FROM ( '
                      ||'SELECT '
                      ||'TSA_YEAR TSA_YEAR '
                      ||', SCHOOL_ID SCHOOL_ID '
                      ||', decode(CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',CLASS_LEVEL) CLASS_LEVEL '
                      ||', SUBJECT_CODE SUBJECT_CODE '
                      ||', substr(EXT_ITEM_CODE, instr(EXT_ITEM_CODE, ''T'') +3, 1) DIMENSION '
                      ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(PAPER_CODE, 1, 2) || SUBSTR(PAPER_CODE, 4), PAPER_CODE) PAPER_CODE '
                      ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(EXT_ITEM_CODE, 1, 1) || MATH_ITEM_CODE, EXT_ITEM_CODE) ITEM_CODE '
                      ||', (CANDIDATE_NO||PAPER_CODE) CANDIDATE_NO '
                      ||', sum(DECODE(scored_ans_mark,''U'',0,''Z'',0,scored_ans_mark))/COUNT(NVL(MARKER_SEQ,1)) total_mark '
                      ||'FROM ( '
                      ||'select '
                      ||'TCM.TSA_YEAR '
                      ||', TCA.SCHOOL_ID '
                      ||', TCM.CLASS_LEVEL '
                      ||', TCM.SUBJECT_CODE '
                      ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) EXT_ITEM_CODE '
                      ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),3) MATH_ITEM_CODE '
                      ||', TCM.PAPER_CODE '
                      ||', TCA.CANDIDATE_NO '
                      ||', TCA.scored_ans_mark '
                      ||', TCA.MARKER_SEQ '
                      ||'from '
                      ||'TSA_DATA_CB_HIST TDCH '
                      ||', TSA_COMBINED_MASTER TCM '
                      ||', TSA_COMBINED_ANS TCA '
                      ||'WHERE '
                      ||'TDCH.REQUEST_ID = TCM.REQUEST_ID '
                      ||'AND TCM.COMBINED_MASTER_ID = TCA.COMBINED_MASTER_ID '
                      ||'AND TDCH.ACCEPTANCE = ''A'' '
                      ||'AND TDCH.AUTO_MARKED = ''Y'' '
                      ||'AND decode(TCM.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TCM.CLASS_LEVEL) = :sch_level '
                      ||'AND TCA.INT_TYPE = ''OMR'' '   -- added for TechnicalSpec-RptBatchFunctSP_V9.5 ( 6.15.1, 6.15.5)
                      ||'AND TCM.TSA_YEAR = :TSA_YEAR '
                      ||'AND TCA.SCHOOL_ID = :sch_id ';
                      --||'AND ((TCM.CLASS_LEVEL = ''KS1'' AND TCM.SUB_DIMENSION <> ''CA'') OR TCM.CLASS_LEVEL in (''KS2'',''KS3'')) '
          IF (v_sch_level = 'P' AND v_class_level = 'P3') THEN
            v_sql_temp := v_sql_temp || 'AND TCM.CLASS_LEVEL = ''KS1'' AND TCM.SUB_DIMENSION <> ''CA'' ';
          ELSIF (v_sch_level = 'P' AND v_class_level = 'P6') THEN
            v_sql_temp := v_sql_temp || 'AND TCM.CLASS_LEVEL = ''KS2'' ';
          ELSIF (v_sch_level = 'P' AND v_class_level IS NULL) THEN
            v_sql_temp := v_sql_temp || 'AND ((TCM.CLASS_LEVEL = ''KS1'' AND TCM.SUB_DIMENSION <> ''CA'') OR TCM.CLASS_LEVEL = ''KS2'') ';
          END IF;
          v_sql_temp := v_sql_temp ||'union all '
                      ||'select '
                      ||'TCM.TSA_YEAR '
                      ||', TCA.SCHOOL_ID '
                      ||', TCM.CLASS_LEVEL '
                      ||', TCM.SUBJECT_CODE '
                      ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) EXT_ITEM_CODE '
                      ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),3) MATH_ITEM_CODE '
                      ||', TCM.PAPER_CODE '
                      ||', TCA.CANDIDATE_NO '
                      ||', TCA.scored_ans_mark '
                      ||', TCA.MARKER_SEQ '
                      ||'from '
                      ||'TSA_COMBINED_MASTER TCM '
                      ||', TSA_COMBINED_ANS TCA '
                      ||'WHERE '
                      ||'0 = TCM.REQUEST_ID '
                      ||'AND TCM.COMBINED_MASTER_ID = TCA.COMBINED_MASTER_ID '
                      ||'AND decode(TCM.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TCM.CLASS_LEVEL) = :sch_level '
                      ||'AND TCA.INT_TYPE = ''OMR'' '   -- added for TechnicalSpec-RptBatchFunctSP_V9.5 ( 6.15.1, 6.15.5)
                      ||'AND TCM.TSA_YEAR = :TSA_YEAR '
                      ||'AND TCA.SCHOOL_ID = :sch_id ';
                      --||'AND ((TCM.CLASS_LEVEL = ''KS1'' AND TCM.SUB_DIMENSION <> ''CA'') OR TCM.CLASS_LEVEL in (''KS2'',''KS3'')) '
          IF (v_sch_level = 'P' AND v_class_level = 'P3') THEN
            v_sql_temp := v_sql_temp || 'AND TCM.CLASS_LEVEL = ''KS1'' AND TCM.SUB_DIMENSION <> ''CA'' ';
          ELSIF (v_sch_level = 'P' AND v_class_level = 'P6') THEN
            v_sql_temp := v_sql_temp || 'AND TCM.CLASS_LEVEL = ''KS2'' ';
          ELSIF (v_sch_level = 'P' AND v_class_level IS NULL) THEN
            v_sql_temp := v_sql_temp || 'AND ((TCM.CLASS_LEVEL = ''KS1'' AND TCM.SUB_DIMENSION <> ''CA'') OR TCM.CLASS_LEVEL = ''KS2'') ';
          END IF;
          v_sql_temp := v_sql_temp || ') '
                      ||'GROUP BY TSA_YEAR, SCHOOL_ID, decode(CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',CLASS_LEVEL), SUBJECT_CODE, substr(EXT_ITEM_CODE, instr(EXT_ITEM_CODE, ''T'') +3, 1), DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(PAPER_CODE, 1, 2) || SUBSTR(PAPER_CODE, 4), PAPER_CODE), DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(EXT_ITEM_CODE, 1, 1) || MATH_ITEM_CODE, EXT_ITEM_CODE), (CANDIDATE_NO||PAPER_CODE) '
                      ||'UNION ALL '
                      ||'SELECT '
                      ||'TSA_YEAR TSA_YEAR '
                      ||', SCHOOL_ID SCHOOL_ID '
                      ||', decode(CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',CLASS_LEVEL) CLASS_LEVEL '
                      ||', SUBJECT_CODE SUBJECT_CODE '
                      ||', substr(EXT_ITEM_CODE, instr(EXT_ITEM_CODE, ''T'') +3, 1) DIMENSION '
                      ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(PAPER_CODE, 1, 2) || SUBSTR(PAPER_CODE, 4), PAPER_CODE) PAPER_CODE '
                      ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(EXT_ITEM_CODE, 1, 1) || MATH_ITEM_CODE, EXT_ITEM_CODE) ITEM_CODE '
                      ||', (CANDIDATE_NO||PAPER_CODE) CANDIDATE_NO '
                      ||', sum(DECODE(scored_ans_mark,''U'',0,''Z'',0,scored_ans_mark))/COUNT(NVL(MARKER_SEQ,1)) total_mark '
                      ||'FROM ( '
                      ||'select '
                      ||'TCM.TSA_YEAR '
                      ||', TCA.SCHOOL_ID '
                      ||', TCM.CLASS_LEVEL '
                      ||', TCM.SUBJECT_CODE '
                      ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) EXT_ITEM_CODE '
                      ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),3) MATH_ITEM_CODE '
                      ||', TCM.PAPER_CODE '
                      ||', TCA.CANDIDATE_NO '
                      ||', TCA.scored_ans_mark '
                      ||', TCA.MARKER_SEQ '
                      ||'from '
                      ||'TSA_DATA_CB_HIST TDCH '
                      ||', TSA_COMBINED_MASTER TCM '
                      ||', TSA_COMBINED_ANS TCA , TSA_MS_QUESTION TMQ , tsa_ms tm '
                      ||'WHERE '
                      ||'TDCH.REQUEST_ID = TCM.REQUEST_ID '
                      ||'AND TCM.COMBINED_MASTER_ID = TCA.COMBINED_MASTER_ID '
                      ||'AND SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) = TMQ.ITEM_CODE '
                      ||'AND EXTRACTVALUE(TMQ.OSM_MS_DTL, ''/ROOT/SHOW_IN_REPORT'') = ''Y'' '
                      ||'AND TDCH.ACCEPTANCE = ''A'' '
                      ||'AND TDCH.AUTO_MARKED = ''Y'' '
                      ||'AND decode(TCM.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TCM.CLASS_LEVEL) = :sch_level '
                      ||'AND TCA.INT_TYPE = ''OSM'' '
                      ||'AND TCM.TSA_YEAR = :TSA_YEAR '
                      ||'AND TCA.SCHOOL_ID = :sch_id '
                      ||'and tm.tsa_year = :TSA_YEAR '
                      ||'and tm.paper_code=tcm.paper_code '
                      ||'and tm.ms_id= tmq.ms_id '
                      ||'and decode(tm.subject_code,''EMATH'',''MATH'',''CMATH'',''MATH'',tm.subject_code) = tcm.subject_code '
                      ||'and tm.class_level = tcm.class_level ';
                      --||'AND ((TCM.CLASS_LEVEL = ''KS1'' AND TCM.SUB_DIMENSION <> ''CA'') OR TCM.CLASS_LEVEL in (''KS2'',''KS3'')) '
          IF (v_sch_level = 'P' AND v_class_level = 'P3') THEN
            v_sql_temp := v_sql_temp || 'AND TCM.CLASS_LEVEL = ''KS1'' AND TCM.SUB_DIMENSION <> ''CA'' ';
          ELSIF (v_sch_level = 'P' AND v_class_level = 'P6') THEN
            v_sql_temp := v_sql_temp || 'AND TCM.CLASS_LEVEL = ''KS2'' ';
          ELSIF (v_sch_level = 'P' AND v_class_level IS NULL) THEN
            v_sql_temp := v_sql_temp || 'AND ((TCM.CLASS_LEVEL = ''KS1'' AND TCM.SUB_DIMENSION <> ''CA'') OR TCM.CLASS_LEVEL = ''KS2'') ';
          END IF;
          v_sql_temp := v_sql_temp ||'union all '
                      ||'select '
                      ||'TCM.TSA_YEAR '
                      ||', TCA.SCHOOL_ID '
                      ||', TCM.CLASS_LEVEL '
                      ||', TCM.SUBJECT_CODE '
                      ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) EXT_ITEM_CODE '
                      ||', SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),3) MATH_ITEM_CODE '
                      ||', TCM.PAPER_CODE '
                      ||', TCA.CANDIDATE_NO '
                      ||', TCA.scored_ans_mark '
                      ||', TCA.MARKER_SEQ '
                      ||'from '
                      ||'TSA_COMBINED_MASTER TCM '
                      ||', TSA_COMBINED_ANS TCA , TSA_MS_QUESTION TMQ , tsa_ms tm '
                      ||'WHERE '
                      ||'0 = TCM.REQUEST_ID '
                      ||'AND TCM.COMBINED_MASTER_ID = TCA.COMBINED_MASTER_ID '
                      ||'AND SUBSTR (EXTRACTVALUE (TCA.ITEM_CODE,''/ITEM_CODE_INFO/QUESTION/ITEM_CODE''),0,100) = TMQ.ITEM_CODE '
                      ||'AND EXTRACTVALUE(TMQ.OSM_MS_DTL, ''/ROOT/SHOW_IN_REPORT'') = ''Y'' '
                      ||'AND decode(TCM.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TCM.CLASS_LEVEL) = :sch_level '
                      ||'AND TCA.INT_TYPE = ''OSM'' '
                      ||'AND TCM.TSA_YEAR = :TSA_YEAR '
                      ||'AND TCA.SCHOOL_ID = :sch_id '
                      ||'and tm.tsa_year = :TSA_YEAR '
                      ||'and tm.paper_code=tcm.paper_code '
                      ||'and tm.ms_id= tmq.ms_id '
                      ||'and decode(tm.subject_code,''EMATH'',''MATH'',''CMATH'',''MATH'',tm.subject_code) = tcm.subject_code '
                      ||'and tm.class_level = tcm.class_level ';
                      --||'AND ((TCM.CLASS_LEVEL = ''KS1'' AND TCM.SUB_DIMENSION <> ''CA'') OR TCM.CLASS_LEVEL in (''KS2'',''KS3'')) '
          IF (v_sch_level = 'P' AND v_class_level = 'P3') THEN
            v_sql_temp := v_sql_temp || 'AND TCM.CLASS_LEVEL = ''KS1'' AND TCM.SUB_DIMENSION <> ''CA'' ';
          ELSIF (v_sch_level = 'P' AND v_class_level = 'P6') THEN
            v_sql_temp := v_sql_temp || 'AND TCM.CLASS_LEVEL = ''KS2'' ';
          ELSIF (v_sch_level = 'P' AND v_class_level IS NULL) THEN
            v_sql_temp := v_sql_temp || 'AND ((TCM.CLASS_LEVEL = ''KS1'' AND TCM.SUB_DIMENSION <> ''CA'') OR TCM.CLASS_LEVEL = ''KS2'') ';
          END IF;
          v_sql_temp := v_sql_temp ||') '
                      ||'GROUP BY TSA_YEAR '
                      ||', SCHOOL_ID '
                      ||', decode(CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',CLASS_LEVEL) '
                      ||', SUBJECT_CODE '
                      ||', substr(EXT_ITEM_CODE, instr(EXT_ITEM_CODE, ''T'') +3, 1) '
                      ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(PAPER_CODE, 1, 2) || SUBSTR(PAPER_CODE, 4), PAPER_CODE) '
                      ||', DECODE(SUBJECT_CODE, ''MATH'',SUBSTR(EXT_ITEM_CODE, 1, 1) || MATH_ITEM_CODE, EXT_ITEM_CODE) '
                      ||', (CANDIDATE_NO||PAPER_CODE) '
                      ||') '
                      ||'GROUP BY TSA_YEAR, SCHOOL_ID, CLASS_LEVEL, SUBJECT_CODE, DIMENSION, PAPER_CODE, CANDIDATE_NO '
                      ||'UNION '   --removed ALL' 20100726
                      ||'select TSA_YEAR,SCHOOL_ID,CLASS_LEVEL,SUBJECT,DIMENSION,paper_code,CANDIDATE_NO,avg(TOTAL_MARK) TOTAL_MARK '
                      ||'from ( '
                      ||'SELECT '
                      ||'TOUH.TSA_YEAR '
                      ||', (SELECT SCHOOL_ID FROM TEMP_SCHOOL WHERE SCHOOL_CODE = tos.school_code AND STATUS = ''A'') SCHOOL_ID '
                      ||', decode(TOUH.CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',TOUH.CLASS_LEVEL) CLASS_LEVEL '
                      ||', TOUH.SUBJECT '
                      ||', TPM.DIMENSION '
                      ||', TOS.paper_code '
                      ||', TOS.school_code || tos.class_name || tos.class_no CANDIDATE_NO '
                      ||', Nvl(COL1,0)+ Nvl(COL2,0)+ Nvl(COL3,0)+ Nvl(COL4,0)+ decode(COL5,null,0,''A'',0,''B'',0,to_number(COL5)) TOTAL_MARK '
                      ||'FROM '
                      ||'TSA_OSS TOS '
                      ||', tsa_oss_ul_hist TOUH '
                      ||', TSA_PAPER_MASTER TPM '
                      ||'WHERE '
                      ||'tpm.paper_code = tos.paper_code '
                      ||'AND TOS.oss_id=TOUH.oss_id '
                      ||'AND TOUH.TSA_YEAR= :TSA_YEAR '
                      ||'AND TOS.SCHOOL_CODE = :sch_code '
                      ||'AND decode(TOUH.CLASS_LEVEL,''KS1'',''P'',''KS2'',''P'',''KS3'',''S'',TOUH.CLASS_LEVEL) = :sch_level ';
                      --||'AND TOUH.CLASS_LEVEL in (''KS2'',''KS3'') '
          IF (v_class_level IS NULL OR v_class_level <> 'P3') THEN
            v_sql_temp := v_sql_temp || 'AND TOUH.CLASS_LEVEL in (''KS2'',''KS3'') ';
          ELSE
            v_sql_temp := v_sql_temp || 'AND 1 = 0 ';
          END IF;
            v_sql_temp := v_sql_temp ||') group by TSA_YEAR, SCHOOL_ID, CLASS_LEVEL, SUBJECT, DIMENSION, paper_code, CANDIDATE_NO '
                      ||') GROUP BY '
                      ||'TSA_YEAR '
                      ||', SCHOOL_ID '
                      ||', CLASS_LEVEL '
                      ||', SUBJECT_CODE '
                      ||', DIMENSION '
                      ||', PAPER_CODE '
                      ||'ORDER BY '
                      ||'TSA_YEAR '
                      ||', SCHOOL_ID '
                      ||', CLASS_LEVEL '
                      ||', SUBJECT_CODE '
                      ||', DIMENSION '
                      ||', PAPER_CODE ';
          EXECUTE IMMEDIATE v_sql_temp USING v_sch_level,r.TSA_YEAR, rec.v_sch_id, v_sch_level,r.TSA_YEAR, rec.v_sch_id ,v_sch_level,r.TSA_YEAR, rec.v_sch_id ,r.TSA_YEAR,v_sch_level,r.TSA_YEAR, rec.v_sch_id ,r.TSA_YEAR, r.TSA_YEAR, rec.v_sch_code,v_sch_level;
          UTL_FILE.put_line(v_loghandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - ' || rec.v_sch_code || ' KS1 NON-CA,KS2,KS3 End Success');
/*
          v_sql_temp := 'UPDATE TEMP_AVERAGE A SET  A.MAXIMUM_SCORE_A = '
                      ||'NVL((SELECT FULL_MARK FROM ( '
                      ||'SELECT TSA_YEAR, CLASS_LEVEL, SUBJECT_CODE, DIMENSION, PAPER_CODE, SUM (FULL_MARK) FULL_MARK FROM ( '
                      ||'SELECT DISTINCT MS.TSA_YEAR '
                      ||'  , decode(MS.CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',MS.CLASS_LEVEL) CLASS_LEVEL '
                      ||'  , DECODE(MS.SUBJECT_CODE, ''EMATH'', ''MATH'', ''CMATH'',''MATH'',MS.SUBJECT_CODE ) SUBJECT_CODE '
                      ||'  , substr(TMQ.ITEM_CODE, instr(TMQ.ITEM_CODE, ''T'') +3, 1) DIMENSION '
                      ||'  , (CASE WHEN MS.SUBJECT_CODE IN (''CMATH'',''EMATH'') THEN (SUBSTR(MS.PAPER_CODE, 1, 2) || SUBSTR(MS.PAPER_CODE, 4)) ELSE MS.PAPER_CODE END) PAPER_CODE '
                      ||'  , (CASE WHEN MS.SUBJECT_CODE IN (''CMATH'',''EMATH'') THEN SUBSTR(TMQ.ITEM_CODE,1,1)||SUBSTR(TMQ.ITEM_CODE,3) ELSE TMQ.ITEM_CODE END) ITEM_CODE '
                      ||'  , TO_NUMBER(TMQ.FULL_MARK) FULL_MARK '
                      ||'FROM TSA_MS MS '
                      ||', TSA_MS_QUESTION TMQ '
                      ||'WHERE MS.MS_ID = TMQ.MS_ID '
                      ||'AND TMQ.FULL_MARK <> ''NA'' '
                      ||'AND MS.TSA_YEAR= :1 '
                      ||'AND (((MS.CLASS_LEVEL = ''KS1'' or MS.CLASS_LEVEL = ''KS2'') AND ''P'' = :2) OR (MS.CLASS_LEVEL = ''KS3'' AND ''S'' = :3)) '
                      ||') '
                      ||'GROUP BY '
                      ||'  TSA_YEAR, CLASS_LEVEL, SUBJECT_CODE, DIMENSION, PAPER_CODE '
                      ||'UNION ALL '
                      ||'SELECT '
                      ||'TMO.TSA_YEAR '
                      ||', DECODE(TMO.CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',TMO.CLASS_LEVEL) CLASS_LEVEL '
                      ||', TMO.SUBJECT_CODE '
                      ||', TPM.DIMENSION '
                      ||', TMO.PAPER_CODE '
                      ||', SUM (TMOC.FULL_MARK) FULL_MARK '
                      ||'FROM '
                      ||'TSA_MS_ORAL TMO '
                      ||', TSA_MS_ORAL_CRIT TMOC '
                      ||', TSA_PAPER_MASTER TPM '
                      ||'WHERE '
                      ||'TPM.PAPER_CODE = TMO.PAPER_CODE '
                      ||'AND TMO.MS_ORAL_ID = TMOC.MS_ORAL_ID '
                      ||'AND TMO.TSA_YEAR= :4 '
                      ||'AND (((TMO.CLASS_LEVEL = ''KS1'' or TMO.CLASS_LEVEL = ''KS2'') AND ''P'' = :5) OR (TMO.CLASS_LEVEL = ''KS3'' AND ''S'' = :6)) '
                      ||'GROUP BY '
                      ||'TMO.TSA_YEAR '
                      ||', DECODE(TMO.CLASS_LEVEL,''KS1'',''P3'',''KS2'',''P6'',''KS3'',''S3'',TMO.CLASS_LEVEL) '
                      ||', TMO.SUBJECT_CODE '
                      ||', TPM.DIMENSION '
                      ||', TMO.PAPER_CODE '
                      ||') B '
                      ||'WHERE A.TSA_YEAR = B.TSA_YEAR '
                      ||'AND A.CLASS_LEVEL = B.CLASS_LEVEL '
                      ||'AND A.SUBJECT_CODE = B.SUBJECT_CODE '
                      ||'AND A.DIMENSION = B.DIMENSION '
                      ||'AND A.PAPER_CODE = B.PAPER_CODE '
                      ||'AND A.SCHOOL_ID = :7 ),0) ';
          EXECUTE IMMEDIATE v_sql_temp USING r.TSA_YEAR,v_sch_level,v_sch_level, r.TSA_YEAR,v_sch_level,v_sch_level,rec.v_sch_id;
*/
          v_sql_temp := 'INSERT INTO TEMP_AVERAGE '
                      ||'select tsa_year, school_id, class_level, subject_code,  ''Z'', paper_code, max(number_student), max(number_student), sum(maximum_score_a), sum(school_avg_b), sum(TOTAL_SCORE) '
                      ||'from TEMP_AVERAGE '
                      ||'where subject_code = ''MATH'' '
                      ||'AND SCHOOL_ID = :1 '
                      ||'group by tsa_year, school_id, class_level, subject_code, paper_code ';
          EXECUTE IMMEDIATE v_sql_temp USING rec.v_sch_id;

                                   --Begin added 20100708
/*
          v_sql_temp := 'update TEMP_AVERAGE b '
                      ||'set b.SCHOOL_AVG_B = b.SCHOOL_AVG_B/b.MAXIMUM_SCORE  (select  max(a.MAXIMUM_SCORE_A) from TEMP_AVERAGE a '
                      ||'where a.tsa_year = :1 '
                      ||'and a.subject_code = ''ENG'' '
                      ||'and a.dimension = ''S'' '
                      ||'and a.tsa_year = b.tsa_year '
                      ||'and a.class_level = b.class_level '
                      ||'group by a.tsa_year, a.class_level) '
                      ||'where b.tsa_year = :2 '
                      ||'and b.school_id = 0 '
                      ||'and b.subject_code = ''ENG'' '
                      ||'and b.dimension = ''S'' '
                      ||'and (((b.class_level = ''P3'' or b.class_level = ''P6'') and ''P'' = :3) '
                      ||'  or '
                      ||'  (b.class_level = ''S3'' and ''S'' = :4))';
          EXECUTE IMMEDIATE v_sql_temp USING r.TSA_YEAR,r.TSA_YEAR,v_sch_level,v_sch_level;

          v_sql_temp := 'update TEMP_AVERAGE b '
                      ||'set b.MAXIMUM_SCORE_A =  (select  max(a.MAXIMUM_SCORE_A) from TEMP_AVERAGE a '
                      ||'where a.tsa_year = :1 '
                      ||'and a.subject_code = ''ENG'' '
                      ||'and a.dimension = ''S'' '
                      ||'and a.tsa_year = b.tsa_year '
                      ||'and a.class_level = b.class_level '
                      ||'group by a.tsa_year, a.class_level) '
                      ||'where b.tsa_year = :2 '
                      ||'and b.school_id = 0 '
                      ||'and b.subject_code = ''ENG'' '
                      ||'and b.dimension = ''S'' '
                      ||'and (((b.class_level = ''P3'' or b.class_level = ''P6'') and ''P'' = :3) '
                      ||'  or '
                      ||'  (b.class_level = ''S3'' and ''S'' = :4))';
          EXECUTE IMMEDIATE v_sql_temp USING r.TSA_YEAR,r.TSA_YEAR,v_sch_level,v_sch_level;
*/
                                   --End added 20100708

          Delete from TSA_RPT_SCH
          Where tsa_year = r.TSA_YEAR
          And School_id = rec.v_sch_id
          AND (('P' = v_sch_level AND ((v_class_level IS NULL AND CLASS_LEVEL IN ('P3','P6')) OR (v_class_level IS NOT NULL AND CLASS_LEVEL = v_class_level))) OR ('S' = v_sch_level AND CLASS_LEVEL = 'S3'));

          V_DATE := TRUNC(SYSDATE,'MI');
          v_sql_temp := 'INSERT INTO TSA_RPT_SCH '
                      ||'SELECT A.*, :1, :2, :3, :4 '
                      ||'FROM TEMP_PERCENTAGE A '
                      ||'WHERE SCHOOL_ID = :5 '
                      ||'AND TSA_YEAR = :6 ';  -- Added by Ady for Exception Happen: ORA-00001: unique constraint (TSADBA.TSA_RPT_SCH_PK) violated on 2012-05-22
          EXECUTE IMMEDIATE v_sql_temp USING V_DATE,r.CREATED_BY,V_DATE,r.CREATED_BY,rec.v_sch_id, r.TSA_YEAR;

          Delete from TSA_RPT_SCH_SP
          Where tsa_year = r.TSA_YEAR
          And School_id = rec.v_sch_id
          AND (('P' = v_sch_level AND ((v_class_level IS NULL AND CLASS_LEVEL IN ('P3','P6')) OR (v_class_level IS NOT NULL AND CLASS_LEVEL = v_class_level))) OR ('S' = v_sch_level AND CLASS_LEVEL = 'S3'));

          V_DATE := TRUNC(SYSDATE,'MI');
          v_sql_temp := 'INSERT INTO TSA_RPT_SCH_SP(TSA_YEAR, SCHOOL_ID, CLASS_LEVEL, SUBJECT_CODE, DIMENSION, SUB_PAPER_CODE, NUMBER_OF_STUDENT, RATED_NUM_OF_STUDENT, SCH_MAX_SCORE, SCH_AVG_SCORE, TOTAL_SCORE, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE, LAST_UPDATED_BY ) '
                      --||'SELECT A.*, :1, :2, :3, :4 '
                      ||'SELECT TSA_YEAR,SCHOOL_ID,CLASS_LEVEL,SUBJECT_CODE,DIMENSION,PAPER_CODE,NUMBER_STUDENT,WEIGHT_NUM_OF_STUDENT,MAXIMUM_SCORE_A,SCHOOL_AVG_B,TOTAL_SCORE, :1, :2, :3, :4 '
                      ||'FROM TEMP_AVERAGE A '
                      ||'WHERE SCHOOL_ID = :5 ';
          EXECUTE IMMEDIATE v_sql_temp USING V_DATE,r.CREATED_BY,V_DATE,r.CREATED_BY,rec.v_sch_id;

          v_sql_temp := 'INSERT INTO TEMP_OUT_SCHOOL_RESULT_SCH VALUES(:1, :2, :3, :4, ''C'') ';
          EXECUTE IMMEDIATE v_sql_temp USING r.REQUEST_ID, r.TSA_YEAR, rec.v_sch_code, v_sch_level;


          -- delete the data of TSA_RPT_SUPP_SCH_SCHOOL
          EXECUTE IMMEDIATE  ' DELETE FROM TSA_RPT_SCHOOL_SCHOOL WHERE ACADEMIC_YEAR = ' || R.Tsa_Year || ' - 1 AND SCHOOL_ID = ' || Rec.V_Sch_Id ;
          -- the sql add by Jay for CR00046
          v_sql_temp := 'INSERT INTO TSA_RPT_SCHOOL_SCHOOL '
                      ||' SELECT DISTINCT '
                      ||' SCH.SCHOOL_ID '
                      ||' , SCH.SCHOOL_CODE '
                      ||' , SCH.NAME_CN AS NAME_CN '
                      ||' , SCH.NAME_EN AS NAME_EN '
                      ||' , LP_3.LOOKUP_MEANING AS SESSION_CN '
                      ||' , LP_2.LOOKUP_MEANING AS SESSION_EN '
                      ||' , CLS.CLASS_LEVEL '
                      ||' , LP_1.LOOKUP_MEANING CLASS_LEVEL_CHI '
                      ||' , LP_4.LOOKUP_MEANING CLASS_LEVEL_ENG '
                      ||' , CLS.ACADEMIC_YEAR '
                      ||' , :1 '
                      ||' , :2 '
                      ||' , :3 '
                      ||' , :4 '
                      ||' FROM '
                      ||' BCA_CLASS CLS '
                      ||' , BCA_SCHOOL SCH '
                      ||' , BCA_LOOKUP LP_1 '
                      ||' , BCA_LOOKUP LP_2 '
                      ||' , BCA_LOOKUP LP_3 '
                      ||' , BCA_LOOKUP LP_4 '
                      ||' WHERE SCH.SCHOOL_ID = CLS.SCHOOL_ID ';
                      If Rec.V_Sch_Code Is Not Null Then
                      v_sql_temp := v_sql_temp || ' AND SCH.SCHOOL_CODE = ''' || rec.v_sch_code || ''' ';
                      End If;
                      V_Sql_Temp := V_Sql_Temp ||  ' AND SCH.SCHOOL_LEVEL = :5 '--<Value of school level>
                      ||' AND SCH.TSA_FLAG =''Y'' '
                      ||' AND SCH.STATUS = ''A'' '
                      ||' AND CLS.ACADEMIC_YEAR = :6 - 1 '
                      ||' AND LP_1.LOOKUP_TYPE = ''TSA_IA_CLASS_LEVEL'' '
                      ||' AND LP_1.LANGUAGE = ''ZH'' '
                      ||' AND LP_1.LOOKUP_CODE = DECODE(CLS.CLASS_LEVEL,''P3'',''KS1'',''P6'',''KS2'',''S3'',''KS3'') '
                      ||' AND LP_2.LOOKUP_TYPE = ''TSA_SESSION'' '
                      ||' AND LP_2.LANGUAGE = ''EN'' '
                      ||' AND LP_2.LOOKUP_CODE = SCH.SCHOOL_SESSION '
                      ||' AND LP_3.LOOKUP_TYPE = ''TSA_SESSION'' '
                      ||' AND LP_3.LANGUAGE = ''ZH'' '
                      ||' AND LP_3.LOOKUP_CODE = SCH.SCHOOL_SESSION '
                      ||' AND LP_4.LOOKUP_TYPE = ''TSA_IA_CLASS_LEVEL'' '
                      ||' AND LP_4.LANGUAGE = ''EN'' '
                      ||' AND LP_4.LOOKUP_CODE = DECODE(CLS.CLASS_LEVEL,''P3'',''KS1'',''P6'',''KS2'',''S3'',''KS3'') '
                      ||' AND CLS.CLASS_ID IN ( '
                      ||' SELECT '
                      ||' B.CLASS_ID '
                      ||' FROM '
                      ||' BCA_SCHOOL A, '
                      ||' BCA_CLASS B, '
                      ||' BCA_STUDENT C '
                      ||' WHERE '
                      ||' A.SCHOOL_ID = C.SCHOOL_ID '
                      ||' AND C.CLASS_ID = B.CLASS_ID '
                      ||' AND C.ACADEMIC_YEAR = :7 - 1 '
                      ||' AND B.ACADEMIC_YEAR = :8 - 1 '
                      ||' AND C.STATUS <>''DE'' '
                      ||' AND C.TSA_ENROL_FLAG= ''Y'' '
                      ||' UNION ALL '
                      --change by Jay 20120803 start
                      ||' SELECT CLASS_ID FROM ( '
                      ||' SELECT '
                      ||' B.*, ROW_NUMBER() OVER ( '
                      ||' PARTITION BY ACADEMIC_YEAR, SCHOOL_ID, CLASS_ID, CLASS_NO '
                      ||' ORDER BY CREATION_DATE DESC, LAST_UPDATE_DATE DESC) CLASSNO_SEQ '
                      ||' FROM ( '
                      ||' SELECT '
                      ||' A.*, ROW_NUMBER() OVER ( '
                      ||' PARTITION BY ACADEMIC_YEAR, STRN '
                      ||' ORDER BY CREATION_DATE DESC, LAST_UPDATE_DATE DESC '
                      ||' ) STRN_SEQ '
                      ||' FROM ( '
                      ||' SELECT '
                      ||' ACADEMIC_YEAR, SCHOOL_ID, CLASS_ID, STUDENT_ID, CLASS_NO, TSA_ENROL_FLAG, STRN, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE, STATUS, '
                      ||' GENDER, STUDENT_NAME_EN, STUDENT_NAME_CN '
                      ||' FROM BCA_STUDENT_HIST BSH '
                      ||' WHERE ACADEMIC_YEAR = TO_CHAR(:9- 1) '
                      ||' AND BSH.STUDENT_ID NOT IN '
                      ||' ( '
                      ||' SELECT BS.STUDENT_ID '
                      ||' FROM BCA_STUDENT BS '
                      ||' WHERE BS.STATUS IN (''EN'',''RE'') '
                      ||' AND BS.ACADEMIC_YEAR= TO_CHAR(:10 - 1) '
                      ||' AND BS.STUDENT_ID =BSH.STUDENT_ID'
                      ||' ) '
                      ||' AND BSH.STRN NOT IN ( '
                      ||' SELECT '
                      ||' BS.STRN '
                      ||' FROM '
                      ||' BCA_STUDENT BS '
                      ||' WHERE '
                      ||' BS.STATUS IN ( '
                      ||' ''EN'',''RE'' '
                      ||' ) '
                      ||' AND BS.ACADEMIC_YEAR= TO_CHAR(:11 - 1) '
                      ||' AND BS.STRN =BSH.STRN '
                      ||' ) '
                      ||' AND not exists ( '
                      ||' SELECT '
                      ||' bs.school_id, bs.class_id, bs.class_no '
                      ||' FROM '
                      ||' BCA_STUDENT BS '
                      ||' WHERE '
                      ||' BS.STATUS IN ( '
                      ||' ''EN'',''RE'' '
                      ||' ) '
                      ||' AND BS.ACADEMIC_YEAR= TO_CHAR(:12 - 1) '
                      ||' AND bs.school_id = bsh.school_id '
                      ||' and bs.class_id = bsh.class_id '
                      ||' and bs.class_no= bsh.class_no '
                      ||' ) '
                      ||' AND BSH.CREATION_DATE = '
                      ||' ( '
                      ||' SELECT MAX(BS2.CREATION_DATE) '
                      ||' FROM BCA_STUDENT_HIST BS2 '
                      ||' WHERE BSH.STUDENT_ID =BS2.STUDENT_ID '
                      ||' AND BSH.ACADEMIC_YEAR = BS2.ACADEMIC_YEAR '
                      ||' AND BSH.ACADEMIC_YEAR = TO_CHAR(:13- 1) '
                      ||' AND BS2.LAST_UPDATE_DATE = '
                      ||' ( '
                      ||' SELECT MAX(BS3.LAST_UPDATE_DATE) '
                      ||' FROM BCA_STUDENT_HIST BS3 '
                      ||' WHERE BS2.STUDENT_ID =BS3.STUDENT_ID '
                      ||' AND BS3.ACADEMIC_YEAR= BS2.ACADEMIC_YEAR '
                      ||' AND BS3.ACADEMIC_YEAR= TO_CHAR(:14 - 1) '
                      ||' ) '
                      ||' ) '
                      ||' AND BSH.LAST_UPDATE_DATE = '
                      ||' ( '
                      ||' SELECT MAX(BS2.LAST_UPDATE_DATE) '
                      ||' FROM BCA_STUDENT_HIST BS2 '
                      ||' WHERE BSH.STUDENT_ID =BS2.STUDENT_ID '
                      ||' AND BSH.ACADEMIC_YEAR= BS2.ACADEMIC_YEAR '
                      ||' AND BSH.ACADEMIC_YEAR= TO_CHAR(:15 - 1) '
                      ||' ) '
                      ||' ) A '
                      ||' ) B WHERE STRN_SEQ =1 '
                      ||' ) WHERE CLASSNO_SEQ = 1 '
                      ||' AND TSA_ENROL_FLAG= ''Y'' '
                      --change by Jay 20120803 end
                      ||' ) '
                      ||' ORDER BY CLS.CLASS_LEVEL ';
          EXECUTE IMMEDIATE v_sql_temp USING  V_DATE,R.CREATED_BY,V_DATE,R.CREATED_BY,v_sch_level,R.TSA_YEAR,R.TSA_YEAR,R.TSA_YEAR,R.TSA_YEAR,R.TSA_YEAR,R.TSA_YEAR,R.TSA_YEAR,R.TSA_YEAR,R.TSA_YEAR,R.TSA_YEAR;

          EXCEPTION
          WHEN OTHERS THEN
            ROLLBACK;
            Error_Flag := 'Y';
            IF UTL_FILE.is_open(v_exchandle) THEN
              UTL_FILE.put_line(v_exchandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - ' ||'Exception Happen2: ' || SQLERRM);
              UTL_FILE.put_line(v_exchandle,'  ');
              UTL_FILE.put_line(v_loghandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - Exception Happen2: '|| DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            END IF;

            v_sql_temp := 'INSERT INTO TEMP_OUT_SCHOOL_RESULT_SCH VALUES(:1, :2, :3, :4, ''F'') ';
            EXECUTE IMMEDIATE v_sql_temp USING r.REQUEST_ID, r.TSA_YEAR, rec.v_sch_code, v_sch_level;
          END;

          COMMIT;

          UTL_FILE.put_line(v_exchandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - End processing school: ' || rec.v_sch_code);
          UTL_FILE.put_line(v_exchandle,'  ');
        END LOOP;
      END IF;

      EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        Error_Flag := 'Y';
        IF UTL_FILE.is_open(v_exchandle) THEN
          UTL_FILE.put_line(v_exchandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - ' ||'Exception Happen: ' || SQLERRM);
          UTL_FILE.put_line(v_exchandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - End the batch Job: ' || r.REQUEST_ID);
          UTL_FILE.put_line(v_exchandle,'  ');
          UTL_FILE.put_line(v_loghandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - ' ||'Exception Happen3: ' || SQLERRM);
          UTL_FILE.put_line(v_loghandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - Exception Happen3: '|| DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        END IF;
        v_sql_temp := 'INSERT INTO TEMP_OUT_SCHOOL_RESULT_SCH VALUES(:1, :2, :3, :4, ''F'') ';
        EXECUTE IMMEDIATE v_sql_temp USING r.REQUEST_ID, r.TSA_YEAR, r.SCHOOL_CODE, v_sch_level;
      END;
    END IF;

    IF Error_Flag = 'N' THEN
      UTL_FILE.put_line(v_exchandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - Completed the batch job - Batch Job ID: ' || r.REQUEST_ID );
      UTL_FILE.put_line(v_exchandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - End the batch job: ' || r.REQUEST_ID);
      UTL_FILE.put_line(v_exchandle,'  ');
      UTL_FILE.fclose (v_exchandle);

      UTL_FILE.put_line(v_loghandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - Completed the batch job - Batch Job ID: ' || r.REQUEST_ID );
      UTL_FILE.put_line(v_loghandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - End the batch job: ' || r.REQUEST_ID);
      UTL_FILE.put_line(v_loghandle,'  ');
      ---------------
      exc_log_bfile := BFILENAME(RPTPOSTG_LOG_DIR,v_exc_file_name);
      dbms_lob.createtemporary(exc_log_blob,TRUE);
      dbms_lob.OPEN(exc_log_blob,dbms_lob.lob_readwrite);
      dbms_lob.fileopen(exc_log_bfile);
      exc_log_size :=dbms_lob.getlength(exc_log_bfile);
      dbms_lob.loadfromfile(exc_log_blob,exc_log_bfile,exc_log_size);
      dbms_lob.fileclose(exc_log_bfile);
      -------------
      UPDATE TSA_JOB_REQUESTS
      --SET REQUEST_STATUS = 'C',
      SET EXCEPTION_RPT = exc_log_blob,
          --ACTUAL_COMPLETE_DATE = TRUNC(SYSDATE,'MI'),
          LAST_UPDATE_DATE = TRUNC(SYSDATE,'MI')
      WHERE REQUEST_ID = r.REQUEST_ID;
      COMMIT;
    ELSE
      IF UTL_FILE.is_open(v_exchandle) THEN
        UTL_FILE.put_line(v_exchandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - Error(s) found in the batch job.' );
        UTL_FILE.put_line(v_exchandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - End the batch Job: ' || r.REQUEST_ID);
        UTL_FILE.put_line(v_exchandle,'  ');
        UTL_FILE.fclose (v_exchandle);
      END IF;
      UTL_FILE.put_line(v_loghandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - Error(s) found in the batch job:' || r.REQUEST_ID);
      UTL_FILE.put_line(v_loghandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - End the batch job: ' || r.REQUEST_ID);
      UTL_FILE.put_line(v_loghandle,'  ');
      ---------------
      exc_log_bfile := BFILENAME(RPTPOSTG_LOG_DIR,v_exc_file_name);
      dbms_lob.createtemporary(exc_log_blob,TRUE);
      dbms_lob.OPEN(exc_log_blob,dbms_lob.lob_readwrite);
      dbms_lob.fileopen(exc_log_bfile);
      exc_log_size :=dbms_lob.getlength(exc_log_bfile);
      dbms_lob.loadfromfile(exc_log_blob,exc_log_bfile,exc_log_size);
      dbms_lob.fileclose(exc_log_bfile);
      -------------
      UPDATE TSA_JOB_REQUESTS
      SET REQUEST_STATUS = 'F',
          EXCEPTION_RPT = exc_log_blob,
          ACTUAL_COMPLETE_DATE = TRUNC(SYSDATE,'MI'),
          LAST_UPDATE_DATE = TRUNC(SYSDATE,'MI')
      WHERE REQUEST_ID = r.REQUEST_ID;
      COMMIT;
    END IF;

    BEGIN
      UTL_FILE.FGETATTR(LOCATION=>RPTPOSTG_LOG_DIR,
                       FILENAME=>v_exc_file_name,
                       FEXISTS=>PRESENT,
                       FILE_LENGTH=>FLENGTH,
                       BLOCK_SIZE=>BSize);
      IF present THEN
        UTL_FILE.fremove(RPTPOSTG_LOG_DIR,v_exc_file_name);
      END IF;
    END;

    BEGIN
      UTL_FILE.FGETATTR(LOCATION=>RPTPOSTG_LOG_DIR,
                        FILENAME=>v_data_file_name,
                        FEXISTS=>PRESENT,
                        FILE_LENGTH=>FLENGTH,
                        BLOCK_SIZE=>BSize);
      IF present THEN
        UTL_FILE.fremove(RPTPOSTG_LOG_DIR,v_data_file_name);
      END IF;
    END;

    Error_Flag := 'N';
    COMMIT;
  END LOOP;

  CLOSE CUR_REQUEST_JOB;

  v_sql_temp := 'INSERT INTO TSA_OUT_SCHOOL_RESULT SELECT a.*,sysdate,0,sysdate,0,UPPER(''TSAPostRpt-004'') FROM TEMP_OUT_SCHOOL_RESULT_SCH a ';
  EXECUTE IMMEDIATE v_sql_temp;
  COMMIT;

  EXECUTE IMMEDIATE 'TRUNCATE TABLE TEMP_PERCENTAGE';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE TEMP_AVERAGE';

  v_sql_temp := ' select tsa.request_id,  tsa.tsa_year,  tsa.school_code,  tsa.school_level,  tsa.status , '
              ||' tsa.CLASS_LEVEL CLASS_LEVEL,  '
              ||' NVL(CHI_OPTION,1) CHI_OPTION,NVL(ENG_OPTION,1) ENG_OPTION,NVL(MATH_OPTION,1) MATH_OPTION from ( '
              ||' SELECT  tsaResult.request_id,  tsaResult.tsa_year,  tsaResult.school_code,  tsaResult.school_level,  tsaResult.status ,SCHOOL_ID,allLevel.CLASS_LEVEL '
              ||' FROM TSA_OUT_SCHOOL_RESULT tsaResult,BCA_SCHOOL achCode,TSA_RPTPOST_GENE_HIST genHist,( '
              ||' select ''P'' SCHOOL_LEVEL,''P3'' CLASS_LEVEL2,''P3'' CLASS_LEVEL from dual '
              ||' union all '
              ||' select ''P'' SCHOOL_LEVEL,''P6'' CLASS_LEVEL2,''P6'' CLASS_LEVEL from dual '
              ||' union all '
              ||' select ''P'' SCHOOL_LEVEL,''X'' CLASS_LEVEL2,''P3'' CLASS_LEVEL from dual '
              ||' union all '
              ||' select ''P'' SCHOOL_LEVEL,''X'' CLASS_LEVEL2,''P6'' CLASS_LEVEL from dual '
              ||' union all '
              ||' select ''S'' SCHOOL_LEVEL,''S3'' CLASS_LEVEL2,''S3'' CLASS_LEVEL from dual '
              ||' union all '
              ||' select ''S'' SCHOOL_LEVEL,''X'' CLASS_LEVEL2,''S3'' CLASS_LEVEL from dual '
              ||' ) allLevel '
              ||' WHERE tsaResult.RPT_TYPE = UPPER(''TSAPostRpt-004'') '
              ||' and achCode.SCHOOL_CODE = tsaResult.SCHOOL_CODE '
              ||' and achCode.status = ''A'' '
              ||' and tsaResult.school_level =allLevel.SCHOOL_LEVEL '
              ||' and nvl(genHist.class_level,''X'') =allLevel.CLASS_LEVEL2  '
              ||' and tsaResult.request_id = genHist.request_id   '
              ||' ) tsa, '
              ||' TSA_POST_REPORT_OPTION tsaOption '
              ||' where  '
              ||'   tsa.SCHOOL_ID = tsaOption.SCHOOL_ID(+)     '
              ||' and  tsa.tsa_year = tsaOption.tsa_year(+) '
              ||' and  tsa.CLASS_LEVEL = tsaOption.CLASS_LEVEL(+) '
              ||' order by tsa.request_id,tsa.school_code,tsa.CLASS_LEVEL ';
  open CUR_TSA_QP_ALL for v_sql_temp;

  UTL_FILE.put_line(v_loghandle,'Job end Date & Time: ' || TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI'));
  UTL_FILE.fclose (v_loghandle);

EXCEPTION
  WHEN OTHERS THEN
    UTL_FILE.put_line(v_loghandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - Exception Happen4: '|| SQLERRM);
    UTL_FILE.put_line(v_loghandle,'  ');
    UTL_FILE.put_line(v_loghandle,'Job End Date & Time: ' || TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI'));
    UTL_FILE.put_line(v_loghandle,TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI') || ' - Exception Happen4: '|| DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
    UTL_FILE.fclose (v_loghandle);
END TSA_SP_SCHOOL_CAL;

/

  GRANT EXECUTE ON "TSADBA"."TSA_SP_SCHOOL_CAL" TO "SAWEB";
