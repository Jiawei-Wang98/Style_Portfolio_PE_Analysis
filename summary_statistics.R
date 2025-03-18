process_country_data <- function(country_name) {
  industry_file = paste0(country_name,'_industry.xlsx')
  country_industry <- read_excel(paste0('combined/', industry_file))
  data_file = paste0(country_name,'.xlsx')
  country_data <- read_excel(paste0('combined/', data_file))
  colnames(country_data)[3:ncol(country_data)] <- sapply(colnames(country_data)[3:ncol(country_data)], function(x) {
    # Safely check if the column name is numeric using suppressWarnings and is.na checks
    numeric_val <- suppressWarnings(as.numeric(x))
    if (!is.na(numeric_val)) {
      # Convert the numeric value to date (Excel uses 1900 as the origin for date serial numbers)
      format(as.Date(numeric_val, origin = "1899-12-30"), "%Y-%m")
    } else {
      x  # Return as-is if it's not numeric
    }
  })
  country_data$Type <- gsub("\\(.*?\\)", "", country_data$Code)
  # Merge country and country_industry data on 'Type'
  country_merged_data <- merge(country_data, country_industry, by = 'Type', all = FALSE)
  
  companies_with_values <- list()
  
  # Iterate over each year column
  for (month_column in names(country_merged_data)[4:(ncol(country_merged_data)-4)]) {
    # Drop rows with NA values in the current year column
    temp_df <- na.omit(country_merged_data[, c("Name", month_column)])
    
    # Extract unique company names
    unique_company_names <- unique(sapply(temp_df$Name, function(x) unlist(strsplit(x, " - "))[1]))
    
    # Count unique companies
    num_unique_companies <- length(unique_company_names)
    
    # Store the count for the current year
    companies_with_values[[month_column]] <- num_unique_companies
  }
  
  # Return the list of counts of unique companies with values for each year
  return(companies_with_values)
  
}


date_sequence <- seq(as.Date("1996-09-01"), as.Date("2023-09-01"), by = "month")

# Format the dates to only include year and month (YYYY-MM)
formatted_dates <- format(date_sequence, "%Y-%m")


# Initialize a list to store results for all countries
country_company_with_values1 <- list()

# Process data for each country
for (country in countries) {
  country_results <- process_country_data(country)
  country_company_with_values1[[country]] <- country_results
}


table1_data <- data.frame(matrix(NA, nrow = length(c(countries, "Asia Pacific", "Emerging markets", "Developed markets", "Full sample")), 
                                 ncol = length(formatted_dates)))
rownames(table1_data) <- c(countries, "Asia Pacific", "Emerging markets", "Developed markets", "Full sample")
colnames(table1_data) <- formatted_dates

# Fill country data into table1_data
for (i in seq_along(countries)) {
  country <- countries[i]
  for (month in formatted_dates) {
    # Check if the country has any values in the list
    if (length(country_company_with_values1[[country]]) > 0) {
      # Check if the specific month exists in the country's data
      if (as.character(month) %in% names(country_company_with_values1[[country]])) {
        table1_data[country, as.character(month)] <- country_company_with_values1[[country]][[as.character(month)]]
      }
    }
  }
}

# Fill in the table data for aggregated regions and full sample
aggregated_regions <- list(
  "Asia Pacific" = asia_pacific,
  "Emerging markets" = emerging_markets,
  "Developed markets" = developed_markets,
  "Full sample" = countries
)

# Iterate through regions and calculate the sum for each month
for (region in names(aggregated_regions)) {
  for (month in formatted_dates) {
    # Sum the data for all countries in the region for the given month
    region_sum <- sum(sapply(aggregated_regions[[region]], function(country) {
      if (length(country_company_with_values1[[country]]) > 0 && as.character(month) %in% names(country_company_with_values1[[country]])) {
        return(country_company_with_values1[[country]][[as.character(month)]])
      } else {
        return(0)  # Return 0 if no value is found for the country in that month
      }
    }), na.rm = TRUE)  # Ensures NA values are handled correctly
    table1_data[region, as.character(month)] <- region_sum
  }
}

# Print the resulting table

write.csv(table1_data, "results/table1.csv")
