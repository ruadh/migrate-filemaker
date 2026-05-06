create or replace TRIGGER "SAMPLE_BIU" 
    before insert or update 
    on "SAMPLE"
    for each row
begin
    if inserting then 
        :new.created_on := sysdate; 
        :new.created_by := coalesce(sys_context('APEX$SESSION','APP_USER'),user); 
    end if; 
    :new.updated_on := sysdate; 
    :new.updated_by := coalesce(sys_context('APEX$SESSION','APP_USER'),user); 
end SAMPLE_BIU;
/