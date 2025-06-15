
    DECLARE
        
        table_count NUMBER;
    
    BEGIN
        
        -- テーブルの存在を確認
        SELECT COUNT(*)
        INTO table_count
        FROM user_tables
        WHERE table_name = 'GOVLIST';
    

        -- 
        -- テーブルが存在しない場合のみ実行
    
        
        IF table_count = 0 THEN
    
            EXECUTE IMMEDIATE '
            CREATE TABLE govlist (
                govcode VARCHAR2(255) NOT NULL,
                govname VARCHAR2(255) NOT NULL
            )
            
            ';
        END IF;
        
    END;
    