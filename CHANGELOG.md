# Changelog

This is the changelog for AllyDB. It contains all the changes made to the project.

### 0.6.0

### Added

- Support for sets.

### Changed

- Persistence now starts after the in memory database is fully loaded.
- The `Allydb.Server.serve/1` function is now not returned for errors, so the server will exit properly now.

## 0.5.0

### Changed

- Write and delete operations are now asynchronous. This means that the database will not block the thread that is performing the write operation.

## 0.4.0

### Changed

- Reworked the way the database is persisted. The database now uses a log file to store all the changes made to the database. The interval persistence is now used as a backup.

## 0.3.0

### Added

- Support for hashes.

## 0.2.0

### Added

- Persistence for the database. The database is now saved to a file on disk and loaded on startup.

## 0.1.0

Initial release with basic key value storage and lists support.
