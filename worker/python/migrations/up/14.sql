
    DECLARE
        
        table_count NUMBER;
    
    BEGIN
        
        -- テーブルの存在を確認
        SELECT COUNT(*)
        INTO table_count
        FROM user_tables
        WHERE table_name = 'TABLELIST';
    

        -- 
        -- テーブルが存在しない場合のみ実行
    
        
        IF table_count = 0 THEN
    
            EXECUTE IMMEDIATE '
            CREATE TABLE tablelist (
                statcode VARCHAR2(255) NOT NULL,
                statdispid VARCHAR2(255) NOT NULL,
                title CLOB,
                cycle VARCHAR2(255) NOT NULL,
                survey_date VARCHAR2(255) NOT NULL
            )
            
            ';
        END IF;
        
    END;
    