-- DDL for Foreign Table to OSS for Logging
CREATE FOREIGN TABLE IF NOT EXISTS oss_log_files (
    log_id serial PRIMARY KEY,
    log_filename text,
    log_content text,
    created_at timestamp default now()
) SERVER ossserver OPTIONS (dir 'archivelogdir/');

-- Procedure to Write Log to OSS
CREATE OR REPLACE PROCEDURE TSA_SP_LOG_TO_OSS(
    p_log_filename text,
    p_log_content text
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO oss_log_files (log_filename, log_content) VALUES (p_log_filename, p_log_content);
END;
$$;

-- Converted Procedure from Oracle to PolarDB-O
CREATE OR REPLACE PROCEDURE TSA_SP_SCHOOL_CAL_polar(
    INOUT CUR_TSA_QP_ALL refcursor,
    IN JOB_NAME varchar
)
LANGUAGE plpgsql
AS $$
DECLARE
    -- ...existing code...
    v_log_content text := '';
    v_exc_content text := '';
    v_log_filename text;
    v_exc_filename text;
    -- ...existing code...
BEGIN
    -- ...existing code...
    -- Replace UTL_FILE.fopen and put_line with log accumulation
    v_log_filename := 'TSA_SP_SCHOOL_CAL_' || to_char(now(),'YYYYMMDDHH24MI') || '.log';
    v_log_content := v_log_content || 'Job Log - RPTPOSTG - TSAPostRpt-004 - SCHOOL_CAL\n';
    v_log_content := v_log_content || '\n';
    v_log_content := v_log_content || 'Job Start Date & Time: ' || to_char(now(),'YYYY-MM-DD HH24:MI') || '\n';
    v_log_content := v_log_content || '\n';
    -- ...existing code...
    -- Whenever you would write to v_loghandle, append to v_log_content
    -- Whenever you would write to v_exchandle, append to v_exc_content
    -- At the end, write logs to OSS
    PERFORM TSA_SP_LOG_TO_OSS(v_log_filename, v_log_content);
    IF v_exc_content IS NOT NULL AND v_exc_content <> '' THEN
        v_exc_filename := 'EXC_' || JOB_NAME || '_' || to_char(now(),'YYYYMMDDHH24MI') || '.log';
        PERFORM TSA_SP_LOG_TO_OSS(v_exc_filename, v_exc_content);
    END IF;
    -- ...existing code...
END;
$$;

-- Grant execute as in original
GRANT EXECUTE ON TSA_SP_SCHOOL_CAL_polar TO SAWEB;
