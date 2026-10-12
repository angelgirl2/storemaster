CREATE TABLE IF NOT EXISTS "SchemaVersions" (
  "Version" integer PRIMARY KEY,
  "AppliedAt" timestamptz NOT NULL DEFAULT now()
);
INSERT INTO "SchemaVersions"("Version") VALUES (3) ON CONFLICT ("Version") DO NOTHING;
