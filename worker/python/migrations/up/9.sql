
    DECLARE
        
        table_count NUMBER;
    
    BEGIN
        
        -- テーブルの存在を確認
        SELECT COUNT(*)
        INTO table_count
        FROM user_tables
        WHERE table_name = 'TABLE_DIMENSION';
    

        -- 
        -- テーブルが存在しない場合のみ実行
    
        
        IF table_count = 0 THEN
    
            EXECUTE IMMEDIATE '
            CREATE TABLE table_dimension (
                statdispid VARCHAR2(255) NOT NULL,
                class_name VARCHAR2(255) NOT NULL
            )
            
            ';
        END IF;
        
    END;
    