# library and globals ---------------------

library(shiny)
library(shinydashboard)
library(DT)
library(DBI)
library(shinyjs)


doQuery <- function(sql) {
  conn <- dbConnect(
    drv = RMySQL::MySQL(),
    dbname = "zen",
    host = "localhost",
    username = "zenperson",
    password = "hugo108merton")
  rs <- dbSendQuery(conn, sql)
  results <- dbFetch(rs)
  dbClearResult(rs)
  dbDisconnect(conn)
  results
}

sql <- paste0("select Part_ID as ID, Part_FName as 'First Name', ",
              "Part_Lname as 'Last Name' from participant;")
members <- doQuery(sql)

sql <- paste0("select d.Don_ID as Don_ID, p.Part_ID as Member_ID, p.Part_FName as First, ",
              "p.Part_Lname as Last, d.Don_Amount as Amount, d.Don_Date as Date ",
              "from participant p ",
              "inner join donation d on p.Part_ID =  d.Part_ID ")
donations <- doQuery(sql)

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
    shinyjs::useShinyjs(),
    tabItems(
      tabItem(tabName = "add",
              fluidRow(
                column(width = 6,
                       helpText("Find a member.")
                       ,
                       dataTableOutput("members1")
                )
                ,
                column(width = 6,
                  helpText("Coming Soon!")
                )
              )
      )
      ,
      tabItem(tabName = "modify",
              fluidRow(
                column(width = 9,
                       helpText("Select a donation by clicking on a row in the following table.")
                       ,
                       DT::dataTableOutput("donations")
                )
                ,
                column(width = 3,
                       helpText("Selected Donation:"),
                       br(),
                       uiOutput("donationPartID"),
                       uiOutput("donationAmount"),
                       uiOutput("donationDate"),
                       uiOutput("donationForm")
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
                       donations = donations,
                       donationSelected = NULL,
                       donors = NULL,
                       totals = NULL)
  
  observeEvent(input$donations_rows_selected, {
    id <- rv$donations[input$donations_rows_selected,]$Don_ID
    sql <- paste0("select * from donation where Don_ID = ", id, ";")
    print(sql)
    rv$donationSelected <- doQuery(sql)
  })
  
  observeEvent(input$dates,{
    
    sql <- paste0("select distinct concat(p.Part_Lname, ', ', p.Part_Fname) 'Name', ",
                  "p.Part_Email 'Email' ",
                  "from participant p ",
                  "inner join donation d on p.Part_ID = d.Part_ID ",
                  "where d.Don_Date >= '", input$dates[1],
                  "' and d.Don_Date <= '", input$dates[2],
                  "' order by Name;")
    rv$donors <- doQuery(sql)
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
    rv$totals <- doQuery(sql)
  })

  
  output$members1 <- renderDataTable({
    req(rv$donationSelected)
    rv$members1
  }, options = list(lengthMenu = c(10, 15, 20), pageLength = 8,
                    rownames = F))
  
  output$donations <- DT::renderDataTable({
    rv$donations
  }, options = list(lengthMenu = c(10, 15, 20), pageLength = 8),
     selection = "single", rownames = F)
  
  output$donationPartID <- renderUI({
    req(rv$donationSelected)
    value <- rv$donationSelected$Part_ID
    print(value)
    numericInput("donationPartID", "Member ID", value = value)
  })
  
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
