# library and globals ---------------------

library(shiny)
library(shinydashboard)
library(DT)
library(DBI)
library(pool)
#library(RMySQL) (we will use only one function from this package)

pool <- dbPool(
  drv = RMySQL::MySQL(),
  dbname = "zen",
  
  # connecting to a remote host.
  # in the mysql configuration on this host,
  # make sure to set bind-address	= <ip-address-here>
  #host = "138.197.67.219",
  #port = 3306,
  
  # For local connection use below.
  # (On linux you might also need to set the correct socket, e.g.,
  # for Ubuntu it's /var/run/mysqld/mysqld.sock, not
  # /tmp/mysql.sock as on Mac OS)
  host = "localhost",
  unix.sock = "/var/run/mysqld/mysqld.sock",
  
  # guest has very limited privileges (cannot even commit changes)
  username = "guest",
  password = "guest",
  
  # the three below are set at their default values:
  minSize = 1,
  maxSize = Inf,
  idleTimeout = 60000
)

sqlMembers <- paste0("select Part_ID as ID, Part_FName as 'First Name', ",
              "Part_Lname as 'Last Name' from participant;")
members <- dbGetQuery(pool, sqlMembers)

sqlDonations <- paste0("select d.Don_ID as Don_ID, p.Part_ID as Member_ID, p.Part_FName as First, ",
              "p.Part_Lname as Last, d.Don_Amount as Amount, d.Don_Date as Date, ",
              "d.Don_Form as Form ",
              "from participant p ",
              "inner join donation d on p.Part_ID =  d.Part_ID ")
donations <- dbGetQuery(pool, sqlDonations)

# ui ------------------------------------------

ui <- dashboardPage(
  dashboardHeader(title = "Zen Center Donations"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Add Donation", tabName = "add", icon = icon("user")),
      menuItem("Modify Donation", tabName = "modify", icon = icon("calendar")),
      menuItem("Donors", tabName = "donors", icon = icon("money")),
      menuItem("Totals", tabName = "totals", icon = icon("money"))
    )
  ),
  dashboardBody(
    tabItems(
      tabItem(tabName = "add",
              fluidRow(
                column(width = 9,
                       helpText("Select a member by clikcing on a row from the table below."),
                       br(),
                       dataTableOutput("members1")
                )
                ,
                column(width = 3,
                       helpText("Add the requested information below."),
                       br(),
                       uiOutput("insertAmount"),
                       uiOutput("insertDate"),
                       uiOutput("insertForm"),
                       br(),
                       helpText("When you are ready, record the donation using the ",
                                "button below."),
                       actionButton("insert","Record Donation")
                )
              )
      )
      ,
      tabItem(tabName = "modify",
              fluidRow(
                column(width = 9,
                       helpText("Select a donation by clicking on a row in ",
                                "the following table."),
                       br(),
                       DT::dataTableOutput("donations")
                )
                ,
                column(width = 3,
                       helpText("You may delete the selected donation with the ",
                                "button below."),
                       actionButton("drop", "Delete Donation"),
                       br(),
                       helpText("If you need to change the donor then delete ",
                                "the donation and add a new one. ",
                                "Otherwise, modify the selected donation below."),
                       br(),
                       uiOutput("donationAmount"),
                       uiOutput("donationDate"),
                       uiOutput("donationForm"),
                       br(),
                       helpText("When you are ready submit the update using the ",
                                "button below."),
                       actionButton("update","Submit Update")
                )
              )
      ),
      tabItem(tabName = "donors",
              fluidRow(
                column(width = 3
                       ,
                       helpText("Choose a date range.")
                       ,
                       dateRangeInput("dates", "Dates",start = "2016-01-01",
                                 end = NULL),
                       helpText("You may download a copy of the data as a .csv file."),
                       downloadButton('downloadDonors', 'Download')
                )
                ,
                column(width = 9,
                       dataTableOutput("donors")
                       
                )
              )
      )
      ,
      tabItem(tabName = "totals",
              fluidRow(
                column(width = 3
                       ,
                       helpText("Choose a date range.")
                       ,
                       dateRangeInput("dates2", "Dates",start = "2016-01-01",
                                      end = NULL),
                       helpText("You may download a copy of the data as a .csv file."),
                       downloadButton('downloadTotals', 'Download')
                )
                ,
                column(width = 9,
                       dataTableOutput("totals")
                )
              )
      )
  )
)
)

# server ----------------------------------------

server <- function(input, output, session) {

# reactive values ----------------------------------------------- 
  rv <- reactiveValues(members1 = members,
                       memberSelected = NULL,
                       donations = donations,
                       donationSelected = NULL,
                       donors = NULL,
                       totals = NULL)
  
# observers -----------------------------------------------------
  
  observeEvent(input$members1_rows_selected, {
    id <- rv$members1[input$members1_rows_selected,]$ID
    sql <- paste0("select * from participant where Part_ID = ", id, ";")
    print(sql)
    rv$memberSelected <- dbGetQuery(pool, sql)
  })
  
  observeEvent(input$insert, {
    sql <- paste0("insert into donation (Part_ID, Don_Amount, Don_Date, Don_Form) ",
                  "values (", rv$members1[input$members1_rows_selected,]$ID, ", ",
                  input$insertAmount, ", ",
                  "'", input$insertDate, "', ",
                  "'", input$insertForm, "');")
    print(sql)
    dbGetQuery(pool, sql)
    rv$donations <- dbGetQuery(pool, sqlDonations)
    rv$donationSelected <- NULL
  })
  
  observeEvent(input$donations_rows_selected, {
    id <- rv$donations[input$donations_rows_selected,]$Don_ID
    sql <- paste0("select * from donation where Don_ID = ", id, ";")
    rv$donationSelected <- dbGetQuery(pool, sql)
  })
  
  observeEvent(input$drop, {
    sql <- paste0("delete from donation where Don_ID = ",
                  rv$donationSelected, ";")
    dbGetQuery(pool, sql)
    rv$donations <- dbGetQuery(pool, sqlDonations)
    rv$donationSelected <- NULL
  })
  
  observeEvent(input$update, {
    sql <- paste0("update donation set Part_ID = ", rv$donationSelected$Part_ID, ", ",
                  "Don_Amount = ", input$donationAmount, ", ",
                  "Don_Date = '", input$donationDate, "', ",
                  "Don_Form = '", input$donationForm, "' ",
                  "where Don_ID = ", rv$donationSelected$Don_ID, ";")
    dbGetQuery(pool, sql)
    rv$donations <- dbGetQuery(pool, sqlDonations)
    rv$donationSelected <- NULL
  })
  
  observeEvent(input$dates,{
    
    sql <- paste0("select distinct concat(p.Part_Lname, ', ', p.Part_Fname) 'Name', ",
                  "p.Part_Email 'Email' ",
                  "from participant p ",
                  "inner join donation d on p.Part_ID = d.Part_ID ",
                  "where d.Don_Date >= '", input$dates[1],
                  "' and d.Don_Date <= '", input$dates[2],
                  "' order by Name;")
    rv$donors <- dbGetQuery(pool, sql)
  })
  
  observeEvent(input$dates2,{
    
    sql <- paste0("select distinct concat(p.Part_Lname, ', ', p.Part_Fname) 'Name', ",
                 "concat(p.Part_Address, ', ', p.Part_City, ' ', p.Part_State, ', ', p.Part_Zip) 'Address', ",
                 "sum(d.Don_Amount) 'Total Given' ",
                 "from participant p ",
                 "inner join donation d on p.Part_ID = d.Part_ID ",
                 "where d.Don_Date >= '", input$dates2[1],
                 "' and d.Don_Date <= '", input$dates2[2],
                 "' group by p.Part_ID ",
                 " order by Name;")
    rv$totals <- dbGetQuery(pool, sql)
  })

# output ------------------------------------------------------------
  
  output$members1 <- DT::renderDataTable({
    rv$members1
  }, options = list(lengthMenu = c(10, 15, 20), pageLength = 8),
  selection = "single", rownames = F)
  
  output$insertAmount <- renderUI({
    req(rv$memberSelected)
    numericInput("insertAmount", "Amount", value = 0, min = 0)
  })
  
  output$insertDate <- renderUI({
    req(rv$memberSelected)
    dateInput("insertDate", "Date")
  })
  
  output$insertForm <- renderUI({
    req(rv$memberSelected)
    selectInput("insertForm", "Type of Donation", selected = 'check',
                choices = list('check','cash','card','eft','other'))
  })
  
  output$donations <- DT::renderDataTable({
    rv$donations
  }, options = list(lengthMenu = c(10, 15, 20), pageLength = 8),
     selection = "single", rownames = F)
  
  output$donationAmount <- renderUI({
    req(rv$donationSelected)
    value <- rv$donationSelected$Don_Amount
    numericInput("donationAmount", "Amount", value = value, min = 0)
  })
  
  output$donationDate <- renderUI({
    req(rv$donationSelected)
    value <- rv$donationSelected$Don_Date
    dateInput("donationDate", "Date", value = value)
  })
  
  output$donationForm <- renderUI({
    req(rv$donationSelected)
    value <- rv$donationSelected$Don_Form
    selectInput("donationForm", "Type of Donation", selected = value,
                choices = list('check','cash','card','eft','other'))
  })
  
  output$donRow <- renderDataTable({
    print(input$donations_rows_selected)
    rv$donations[input$donations_rows_selected, ]
  }, options = list(lengthMenu = c(10, 15, 20), pageLength = 8,
                    rownames = F))
  
  output$donors <- renderDataTable({
    rv$donors
  }, options = list(lengthMenu = c(10, 15, 20), pageLength = 8,
                    rownames = F))
  
  output$downloadDonors <- downloadHandler(
    filename = 'donors.csv',
    content = function(file) {
      write.csv(rv$donors, file)
    }
  )
  
  output$totals <- renderDataTable({
    rv$totals
  }, options = list(lengthMenu = c(10, 15, 20), pageLength = 8,
                    rownames = F))
  
  output$downloadTotals <- downloadHandler(
    filename = 'totals.csv',
    content = function(file) {
      write.csv(rv$totals, file)
    }
  )
  
}

# Run the App -------------------------------------

shinyApp(ui, server)
