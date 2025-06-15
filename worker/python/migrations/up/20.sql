
    DECLARE
        
        table_count NUMBER;
        constraint_count NUMBER;
    
    BEGIN
        
        -- テーブルの存在を確認
        SELECT COUNT(*)
        INTO table_count
        FROM user_tables
        WHERE table_name = 'REGION_ITEM';

        -- 制約の存在を確認
        SELECT COUNT(*)
        INTO constraint_count
        FROM all_constraints
        WHERE constraint_name = 'REGION_ITEM_PKEY'
        AND table_name = 'REGION_ITEM';
    

        -- 
        -- テーブルが存在して制約が存在しない場合のみ実行
    
        
        IF table_count = 1 AND constraint_count = 0 THEN
    
            EXECUTE IMMEDIATE '
            ALTER TABLE region_item
                ADD CONSTRAINT region_item_pkey PRIMARY KEY (class_name, name)
            
            ';
        END IF;
        
    END;
    