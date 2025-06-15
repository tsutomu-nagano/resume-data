
    DECLARE
        
        table_count NUMBER;
    
    BEGIN
        
        -- テーブルの存在を確認
        SELECT COUNT(*)
        INTO table_count
        FROM user_tables
        WHERE table_name = 'TAGLIST';
    

        -- 
        -- テーブルが存在する場合のみ実行
    
        
        IF table_count = 1 THEN
    
            EXECUTE IMMEDIATE '
            COMMENT ON TABLE taglist IS ''タグの一覧''
            
            ';
        END IF;
        
    END;
    