# Shiny App to Connect to Zen Database

## Purpose

Example of an app that connects to a MySQL database, permitting the user to modify some tables and to run a couple of pre-defined queries.  It is demonstration-only:  no SQL commit is ever run, so no permanent change is made to the databse.

You may view a working instance that connects to the database remotely at [https://homer.shinyapps.io/ict4405/](https://homer.shinyapps.io/ict4405/).

A working instance that connects locally is at: [http://138.197.67.219:3838/zencenter/](http://138.197.67.219:3838/zencenter/).

## Installation and Setup

You may also run the app on your own machine.  Download this repository, or fork and clone it.

On your local MySQL server:

```
sql> create database zen;
sql> create user 'guest'@'%' identified by 'guest';
sql> grant all insert, delete, update, select on zen.* to 'guest'@'%';
```

To create and populate the tables, you need to run the SQL script `resources/initialize.sql`.  Making sure you are connected to your MySQL server at the root of this repository, run:

```
sql> use zen;
sql> source resources/initialize.sql
```

You may now use the Shiny app.
