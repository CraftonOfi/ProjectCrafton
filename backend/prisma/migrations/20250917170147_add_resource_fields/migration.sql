/*
  Warnings:

  - You are about to drop the column `resourceType` on the `resources` table. All the data in the column will be lost.
  - Added the required column `type` to the `resources` table without a default value. This is not possible if the table is not empty.

*/
-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_resources" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "capacity" TEXT,
    "specifications" TEXT NOT NULL,
    "pricePerHour" REAL,
    "location" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    "type" TEXT NOT NULL,
    "ownerId" INTEGER,
    CONSTRAINT "resources_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "users" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);
INSERT INTO "new_resources" ("capacity", "createdAt", "description", "id", "isActive", "name", "specifications", "updatedAt") SELECT "capacity", "createdAt", "description", "id", "isActive", "name", "specifications", "updatedAt" FROM "resources";
DROP TABLE "resources";
ALTER TABLE "new_resources" RENAME TO "resources";
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
