import logging

from nativesockets import Port, `$`
from times import now, `$`

import
  ../administration/create_standarddata,
  ../utils/logging_nimwc

let nimwcpkgDir = getAppDir().replace("/nimwcpkg", "")
const configFile = "config/config.cfg"
assert existsDir(nimwcpkgDir), "nimwcpkg directory not found: " & nimwcpkgDir
assert existsFile(configFile), "config/config.cfg file not found: " & configFile
setCurrentDir(nimwcpkgDir)

const
  sql_now {.strdefine.} = ""
  sql_timestamp {.strdefine.} = ""
  sql_id {.strdefine.} = "" # http://blog.2ndquadrant.com/postgresql-10-identity-columns
  sqlVacuum {.strdefine.} = ""
  fileBackup {.strdefine.} = ""
  cmdBackup {.strdefine.} = ""
  cmdSign = "gpg --armor --detach-sign --yes --digest-algo sha512 "
  cmdChecksum = "sha512sum --tag "
  cmdTar = "tar cafv "

  personTable = sql("""
    create table if not exists person(
      id         $3            primary key,
      name       varchar(60)   not null,
      password   varchar(300)  not null,
      twofa      varchar(60),
      email      varchar(254)  not null           unique,
      creation   $2            not null           default $1,
      modified   $2            not null           default $1,
      salt       varchar(128)  not null,
      status     varchar(30)   not null,
      timezone   varchar(100),
      secretUrl  varchar(250),
      lastOnline $2            not null           default $1,
      avatar     varchar(300)
    );""".format(sql_now, sql_timestamp, sql_id))

  sessionTable = sql("""
    create table if not exists session(
      id           $3                primary key,
      ip           inet              not null,
      key          varchar(300)      not null,
      userid       integer           not null,
      lastModified $2                not null     default $1,
      foreign key (userid) references person(id)
    );""".format(sql_now, sql_timestamp, sql_id))

  historyTable = sql("""
    create table if not exists history(
      id              $3             primary key,
      user_id         integer        not null,
      item_id         integer,
      element         varchar(100),
      choice          varchar(100),
      text            varchar(1000),
      creation        $2             not null     default $1
    );""".format(sql_now, sql_timestamp, sql_id))

  settingsTable = sql("""
    create table if not exists settings(
      id              $1             primary key,
      analytics       text,
      head            text,
      footer          text,
      navbar          text,
      title           text,
      disabled        integer,
      blogorder       text,
      blogsort        text
    );""".format(sql_id))

  pagesTable = sql("""
    create table if not exists pages(
      id              $3             primary key,
      author_id       INTEGER        NOT NULL,
      status          INTEGER        NOT NULL,
      name            VARCHAR(200)   NOT NULL,
      url             VARCHAR(200)   NOT NULL     UNIQUE,
      title           TEXT,
      metadescription TEXT,
      metakeywords    TEXT,
      description     TEXT,
      head            TEXT,
      navbar          TEXT,
      footer          TEXT,
      standardhead    INTEGER,
      standardnavbar  INTEGER,
      standardfooter  INTEGER,
      tags            VARCHAR(1000),
      category        VARCHAR(1000),
      date_start      VARCHAR(100),
      date_end        VARCHAR(100),
      views           INTEGER,
      public          INTEGER,
      changes         INTEGER,
      modified        $2             not null     default $1,
      creation        $2             not null     default $1,
      foreign key (author_id) references person(id)
    );""".format(sql_now, sql_timestamp, sql_id))

  blogTable = sql("""
    create table if not exists blog(
      id              $3             primary key,
      author_id       INTEGER        NOT NULL,
      status          INTEGER        NOT NULL,
      name            VARCHAR(200)   NOT NULL,
      url             VARCHAR(200)   NOT NULL     UNIQUE,
      title           TEXT,
      metadescription TEXT,
      metakeywords    TEXT,
      description     TEXT,
      head            TEXT,
      navbar          TEXT,
      footer          TEXT,
      standardhead    INTEGER,
      standardnavbar  INTEGER,
      standardfooter  INTEGER,
      tags            VARCHAR(1000),
      category        VARCHAR(1000),
      date_start      VARCHAR(100),
      date_end        VARCHAR(100),
      views           INTEGER,
      public          INTEGER,
      changes         INTEGER,
      pubDate         VARCHAR(100),
      modified        $2             not null     default $1,
      creation        $2             not null     default $1,
      viewCount       INTEGER        NOT NULL     default 1,
      foreign key (author_id) references person(id)
    );""".format(sql_now, sql_timestamp, sql_id))

  filesTable = sql("""
    create table if not exists files(
      id            $3                primary key,
      url           VARCHAR(1000)     NOT NULL     UNIQUE,
      downloadCount integer           NOT NULL     default 1,
      lastModified  $2                NOT NULL     default $1
    );""".format(sql_now, sql_timestamp, sql_id))


proc generateDB*(db: DbConn) =
  info("Database: Generating database tables")

  # User
  if not db.tryExec(personTable):
    info("Database: Could not create table person")

  # Session
  if not db.tryExec(sessionTable):
    info("Database: Could not create table session")

  # History
  if not db.tryExec(historyTable):
    info("Database: Could not create table history")

  # Settings
  if not db.tryExec(settingsTable):
    info("Database: Could not create table settings")

  # Pages
  if not db.tryExec(pagesTable):
    info("Database: Could not create table pages")

  # Blog
  if not db.tryExec(blogTable):
    info("Database: Could not create table blog")

  # Files
  if not db.tryExec(filesTable):
    info("Database: Could not create table files")


proc backupDb*(dbname: string,
    filename = "backup" / fileBackup & replace($now(), ":", "_") & ".sql",
    host = "localhost", port = Port(5432), username = getEnv("USER", "root"),
    dataOnly = false, inserts = false, checksum = true, sign = true, targz = true): tuple[output: TaintedString, exitCode: int] =
  ## Backup the whole Database to a plain-text Raw SQL Query human-readable file.
  preconditions(dbname.len > 0, host.len > 0, username.len > 0,
    when defined(postgres): findExe("pg_dump").len > 0 else: findExe("sqlite3").len > 0)

  discard existsOrCreateDir(nimwcpkgDir / "backup")

  when defined(postgres):
    var cmd = cmdBackup.format(host, $port, username, filename, dbname,
    (if dataOnly: " --data-only " else: "") & (if inserts: " --inserts " else: ""))
  else:  # TODO: SQLite .dump is Not working, Docs says it should.
    var cmd = cmdBackup.format(dbname, filename)

  when not defined(release): info("Database backup: " & cmd)
  result = execCmdEx(cmd)

  if checksum and result.exitCode == 0 and findExe("sha512sum").len > 0:
    cmd = cmdChecksum & filename & " > " & filename & ".sha512"
    when not defined(release): info("Database backup (sha512sum): " & cmd)
    result = execCmdEx(cmd)

    if sign and result.exitCode == 0 and findExe("gpg").len > 0:
      cmd = cmdSign & filename
      when not defined(release): info("Database backup (gpg): " & cmd)
      result = execCmdEx(cmd)

      if targz and result.exitCode == 0 and findExe("tar").len > 0:
        cmd = cmdTar & filename & ".tar.gz " & filename & " " & filename & ".sha512 " & filename & ".asc"

        when not defined(release): info("Database backup (tar): " & cmd)
        result = execCmdEx(cmd)

        if result.exitCode == 0:
          removeFile(filename)
          removeFile(filename & ".sha512")
          removeFile(filename & ".asc")

  if result.exitCode == 0:
    info("Database backup: Done - " & filename)
  else:
    info("Database backup: Fail - " & filename)


template vacuumDb*(db: DbConn): bool =
  echo "Vacuum database (database maintenance)"
  db.tryExec(sql(sqlVacuum))
