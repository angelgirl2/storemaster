DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_storeusers_store') THEN
    ALTER TABLE "StoreUsers" ADD CONSTRAINT fk_storeusers_store FOREIGN KEY ("StoreId") REFERENCES "Stores"("Id") ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_storeusers_user') THEN
    ALTER TABLE "StoreUsers" ADD CONSTRAINT fk_storeusers_user FOREIGN KEY ("UserId") REFERENCES "Users"("Id") ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_licenses_store') THEN
    ALTER TABLE "Licenses" ADD CONSTRAINT fk_licenses_store FOREIGN KEY ("StoreId") REFERENCES "Stores"("Id") ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_devices_storeuser') THEN
    ALTER TABLE "UserDevices" ADD CONSTRAINT fk_devices_storeuser FOREIGN KEY ("StoreId","UserId") REFERENCES "StoreUsers"("StoreId","UserId") ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_cloud_store') THEN
    ALTER TABLE "CloudRecords" ADD CONSTRAINT fk_cloud_store FOREIGN KEY ("StoreId") REFERENCES "Stores"("Id") ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_sync_store') THEN
    ALTER TABLE "SyncChanges" ADD CONSTRAINT fk_sync_store FOREIGN KEY ("StoreId") REFERENCES "Stores"("Id") ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_sync_user') THEN
    ALTER TABLE "SyncChanges" ADD CONSTRAINT fk_sync_user FOREIGN KEY ("UserId") REFERENCES "Users"("Id") ON DELETE RESTRICT;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS "IX_Users_Username_Lower" ON "Users" (lower("Username"));
CREATE INDEX IF NOT EXISTS "IX_StoreUsers_StoreId_Active" ON "StoreUsers" ("StoreId","Active");
CREATE INDEX IF NOT EXISTS "IX_Licenses_StoreId_Status_ExpiresAt" ON "Licenses" ("StoreId","Status","ExpiresAt");
CREATE INDEX IF NOT EXISTS "IX_SyncChanges_StoreId_Id" ON "SyncChanges" ("StoreId","Id");
