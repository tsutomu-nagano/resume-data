
    DECLARE
        
        table_count NUMBER;
        constraint_count NUMBER;
    
    BEGIN
        
        -- テーブルの存在を確認
        SELECT COUNT(*)
        INTO table_count
        FROM user_tables
        WHERE table_name = 'STATLIST';

        -- 制約の存在を確認
        SELECT COUNT(*)
        INTO constraint_count
        FROM all_constraints
        WHERE constraint_name = 'STATLIST_GOVCODE_FKEY'
        AND table_name = 'STATLIST';
    

        -- 
        -- テーブルが存在して制約が存在しない場合のみ実行
    
        
        IF table_count = 1 AND constraint_count = 0 THEN
    
            EXECUTE IMMEDIATE '
            ALTER TABLE statlist
                ADD CONSTRAINT statlist_govcode_fkey FOREIGN KEY (govcode) REFERENCES govlist(govcode) 
            
            ';
        END IF;
        
    END;
    