# Shiny App to Connect to Zen Database

## Purpose

Example of an app that connects to a database, permitting the user to modify some tables and to run a couple of pre-defined queries.  It is deomonstration-only:  no SQL commit is ever run, so no permanent change is made to the databse.

## Installation and Setup

Download this repository, or fork and clone it.

On your local MySQL server:

```
sql> create database zen;
sql> create user 'guest'@'%' identified by 'guest';
sql> grant all privileges on zen.* to 'guest'@'%';
```

To create and populate the tables, you should run the SQL script `resources/initialize.sql`.  Making sure you connected to your MySQL server at the root of this rpeository, you should run:

```
sql> source resources/initialize.sql
```

You may now use the Shiny app.
