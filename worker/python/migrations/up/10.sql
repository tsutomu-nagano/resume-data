
    DECLARE
        
        table_count NUMBER;
    
    BEGIN
        
        -- テーブルの存在を確認
        SELECT COUNT(*)
        INTO table_count
        FROM user_tables
        WHERE table_name = 'TABLE_MEASURE';
    

        -- 
        -- テーブルが存在しない場合のみ実行
    
        
        IF table_count = 0 THEN
    
            EXECUTE IMMEDIATE '
            CREATE TABLE table_measure (
                statdispid VARCHAR2(255) NOT NULL,
                name VARCHAR2(500) NOT NULL
            )
            
            ';
        END IF;
        
    END;
    