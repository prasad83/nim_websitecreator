## Static Postgres/SQLite string constants, do NOT put any run-time logic here, only consts.
from strutils import format
from db_common import sql


when defined(postgres):
  const
    sql_now* = "(extract(epoch from now()))"  # Postgres epoch.
    sql_timestamp* = "integer"
    sql_id* = "integer generated by default as identity"  # http://blog.2ndquadrant.com/postgresql-10-identity-columns
    sqlVacuum* = sql"VACUUM (VERBOSE, ANALYZE);"
else:
  const
    sql_now* = "(strftime('%s', 'now'))"      # SQLite 3 epoch.
    sql_timestamp* = "timestamp"
    sql_id* = "integer"
    sqlVacuum* = sql"VACUUM;"


const
  personTable* = sql("""

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
    );

  """.format(sql_now, sql_timestamp, sql_id))


  sessionTable* = sql("""

    create table if not exists session(
      id           $3                primary key,
      ip           inet              not null,
      key          varchar(300)      not null,
      userid       integer           not null,
      lastModified $2                not null     default $1,
      foreign key (userid) references person(id)
    );

  """.format(sql_now, sql_timestamp, sql_id))


  historyTable* = sql("""

    create table if not exists history(
      id              $3             primary key,
      user_id         integer        not null,
      item_id         integer,
      element         varchar(100),
      choice          varchar(100),
      text            varchar(1000),
      creation        $2             not null     default $1
    );

  """.format(sql_now, sql_timestamp, sql_id))


  settingsTable* = sql("""

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
    );

  """.format(sql_id))


  pagesTable* = sql("""

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
    );

  """.format(sql_now, sql_timestamp, sql_id))


  blogTable* = sql("""

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
    );

  """.format(sql_now, sql_timestamp, sql_id))


  filesTable* = sql("""

    create table if not exists files(
      id            $3                primary key,
      url           VARCHAR(1000)     NOT NULL     UNIQUE,
      downloadCount integer           NOT NULL     default 1,
      lastModified  $2                NOT NULL     default $1
    );

  """.format(sql_now, sql_timestamp, sql_id))
