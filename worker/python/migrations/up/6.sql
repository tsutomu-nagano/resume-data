
    DECLARE
        
        table_count NUMBER;
    
    BEGIN
        
        -- テーブルの存在を確認
        SELECT COUNT(*)
        INTO table_count
        FROM user_tables
        WHERE table_name = 'GOVLIST';
    

        -- 
        -- テーブルが存在する場合のみ実行
    
        
        IF table_count = 1 THEN
    
            EXECUTE IMMEDIATE '
            COMMENT ON TABLE govlist IS ''府省名の一覧''
            
            ';
        END IF;
        
    END;
    