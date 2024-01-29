library(shiny)
library(dplyr)
library(ggplot2)

# Creating UI
ui <- fluidPage(
  title = "Bootstrap Avg Calculator",
  titlePanel(
    tags$h2(style = "margin-bottom: 50px;",
            "Bootstrap Avg Calculator"
    )
  ),
  
  sidebarLayout(
    sidebarPanel(
      fileInput("fileInput", "Upload CSV",
                accept = c("text/csv", "text/comma-separated-values,text/plain", ".csv")),
      uiOutput("metricSelector"),
      tags$br(),
      sliderInput("number_of_samples",
                  "Number of samples:",
                  min = 1000,
                  max = 10000,
                  value = 5000),
      tags$br(),
      downloadButton("downloadExample", "Download sample data")
    ),
    
    mainPanel(
      uiOutput("plotInstructions"),
      plotOutput("histPlot"),
      tags$br(),
      verbatimTextOutput("results")
    )
  )
)


# Server logic
server <- function(input, output, session) {
  
  # Reading file
  data <- reactive({
    req(input$fileInput)
    read.csv(input$fileInput$datapath)
  })
  
  output$downloadExample <- downloadHandler(
    filename = function() {
      "sample_data.csv"
    },
    content = function(file) {
      file.copy("sample_data.csv", file)
    }
  )
  
  # Modal after upload
  observeEvent(input$fileInput, {
    req(data())
    metric_names <- names(data())[sapply(data(), is.numeric) & names(data()) != "var"]
    showModal(modalDialog(
      title = "Choose metrics",
      checkboxGroupInput("selected_metrics", "Choose:", choices = metric_names, selected = metric_names),
      easyClose = TRUE,
      footer = modalButton("Run")
    ))
  })
  
  # Creating buttons
  output$metricSelector <- renderUI({
    req(input$selected_metrics)
    radioButtons("selected_metric", "Metric:", choices = input$selected_metrics)
  })
  
  observe({
    req(input$selected_metric)
    df <- data()
    control_df <- data.frame(metric = df[[input$selected_metric]][df$var == "a"])
    variant_df <- data.frame(metric = df[[input$selected_metric]][df$var == "b"])
    
    mean_control <- mean(control_df$metric, na.rm = TRUE)
    mean_variant <- mean(variant_df$metric, na.rm = TRUE)
    
    # Calculating p-value
    output$results <- renderPrint({
      result <- p_value_with_bootstrapping(control_df, variant_df, "metric", input$number_of_samples)
      cat("Average in control group (A):", mean_control, "\n")
      cat("Average in test group (B):", mean_variant, "\n")
      cat("Mean difference (test - control):", result$difference, "\n")
      cat("P-Value:", result$p_value, "\n")
    })
    
    # Print histogram
    output$histPlot <- renderPlot({
      p_value_with_bootstrapping_plot(control_df, variant_df, "metric", input$number_of_samples)
    })
  })
  
  # Print histogram rules
  output$plotInstructions <- renderUI({
    if (is.null(input$fileInput)) {
      HTML("<div style='text-align: left; padding: 10px;'>
           <h4 style='margin-bottom: 20px;'>To get started, you need to meet 3 requirements for the file:</h4>
           <p>1. All metrics must be <b>numeric format</b>;</p>
           <p>2. Other fields (such as <code>date</code>, <code>var</code>) <b>should not</b> be numeric;</p>
           <p>3. The variant field must be strictly named <code>var</code>. The options are strictly <code>a</code> and <code>b</code>.</p>
           <p>You can download a demo dataset to see how to prepare the file :)</p>
           </div>")
    } else {
      NULL
    }
  })
}


# P-value function
p_value_with_bootstrapping <- function(control_df, variant_df, col_name, number_of_samples) {
  control_values <- control_df[[col_name]]
  variant_values <- variant_df[[col_name]]
  difference <- round(mean(variant_values) - mean(control_values), 3)
  difference_list <- numeric(number_of_samples)
  
  for (i in 1:number_of_samples) {
    first_sample_mean <- mean(sample(control_values, length(control_values), replace = TRUE))
    second_sample_mean <- mean(sample(variant_values, length(variant_values), replace = TRUE))
    difference_list[i] <- second_sample_mean - first_sample_mean
  }
  
  p_value <- 1 - length(which(difference_list > 0)) / number_of_samples
  list(difference = difference, p_value = p_value, difference_list = difference_list)
}

# Histogram function
p_value_with_bootstrapping_plot <- function(control_df, variant_df, col_name, number_of_samples) {
  result <- p_value_with_bootstrapping(control_df, variant_df, col_name, number_of_samples)
  ggplot() +
    geom_histogram(aes(x = result$difference_list), 
                   bins = 50, 
                   fill = "cornflowerblue",
                   col = "white") +
    theme_minimal() +
    labs(x = "Avg difference between samples",
         y = "Difference share")
}


# Run app
shinyApp(ui = ui, server = server)
