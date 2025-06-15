
    DECLARE
        
        table_count NUMBER;
        constraint_count NUMBER;
    
    BEGIN
        
        -- テーブルの存在を確認
        SELECT COUNT(*)
        INTO table_count
        FROM user_tables
        WHERE table_name = 'TABLE_REGION';

        -- 制約の存在を確認
        SELECT COUNT(*)
        INTO constraint_count
        FROM all_constraints
        WHERE constraint_name = 'TABLE_REGION_CLASS_NAME_FKEY'
        AND table_name = 'TABLE_REGION';
    

        -- 
        -- テーブルが存在して制約が存在しない場合のみ実行
    
        
        IF table_count = 1 AND constraint_count = 0 THEN
    
            EXECUTE IMMEDIATE '
            ALTER TABLE table_region
                ADD CONSTRAINT table_region_class_name_fkey FOREIGN KEY (class_name) REFERENCES regionlist(class_name) 
            
            ';
        END IF;
        
    END;
    