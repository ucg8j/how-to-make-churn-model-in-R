suppressPackageStartupMessages({
    library(data.table)   # Fast I/O
    library(dplyr)        # Data munging
    library(tidyr)        # Data munging
    library(lubridate)    # Makes dates easy
})
    
df <- fread('cat /dev/stdin')

# load the model
load("model.rda")

# Assumes date columns
# Reshape data and create new columns
df %<>%
    gather(key = date, value = quantity, starts_with("20")) %>%
    separate(date, c("date","paymentMandate"), "_") %>%
    spread(paymentMandate, quantity) %>%
    mutate(incorporation_date = as.Date(incorporation_date),
           date = as.Date(date),
           incorporation_time = round(as.numeric(difftime(as.Date("2014-12-01"), 
                                                          as.Date(incorporation_date), 
                                                          unit="weeks")) / 52.25,
                                      digits = 1)) %>%
    arrange(date)

# Create binary 'churn' column
df$churn <- 0

# For use in for loop - upper bound of data
max.date <- max(df$date)

# Mark all companies as churned in the month immediately their last activity
for (company in unique(df$company_id)) {
    
    # Subset data to company
    df.sub <- subset(df, df$company_id == company)
    
    # Index of last positive mandate OR payment
    last.pos.idx <- tail(which(df.sub$mandates != 0 | df.sub$payments != 0), 1)
    
    # Get date of last activity
    last.activity.date <- df.sub$date[last.pos.idx]
    
    # If less than max.date of dataset mark churn ELSE do nothing i.e. positive at end of period
    if (last.activity.date < max.date) {
        
        # Get churn date (last positive month plus 1mth)
        churn.date <- last.activity.date %m+% months(1)
        
        # Mark month of churn as 1
        df[df$date == churn.date & df$company_id == company, ]$churn <- 1
    }
}

# Multiple rows per company, filter for last month or churn month values...
# Get churners
df %>% filter(churn == 1) -> churners

# Get max date row of remainers (non-churners)
df %>% 
    filter(churn == 0 & !(company_id %in% churners$company_id) & date == max(date)) -> remainers

# Combine and variables coded ready for modelling
churners %>% 
    rbind(remainers) %>%
    mutate(vertical = as.factor(vertical),
           churn    = as.factor(churn)) -> model.df

# Create binary 'leading_indicator' column
model.df$leading_indicator <- 0

# Min date for which a leading_indicator can be calculated (lower limit of data)
min.date <- min(df$date)

# If month before 'churn' (churn-1), is below the level of mandates of the month 2 months prior (churn-2) then
# make leading_indicator == 1
for (company in churners$company_id) {
    
    # Subset data to company
    df.sub <- subset(df, df$company_id == company)
    
    # Get month prior to churn
    month.prior <- df.sub$date[df.sub$churn == 1] %m-% months(1)
    
    # Get two months prior to churn
    two.month.prior <- df.sub$date[df.sub$churn == 1] %m-% months(2)
    
    # If two months prior is within dataset date range and level of mandates is greater than 0
    if ((two.month.prior > min.date) && (df.sub$mandates[df.sub$date == two.month.prior] > 0)) {
        
        # Compare number of mandates 1 month prior to 2 months prior, if less, mark 'leading_indicator' as '1' 
        if (df.sub$mandates[df.sub$date == month.prior] < df.sub$mandates[df.sub$date == two.month.prior]) {
            model.df[model.df$company_id == company, ]$leading_indicator <- 1
        }
    }
}

# Make predictions
probs <- predict(final.model, newdata = model.df, type = 'response')
binary <- as.factor(ifelse(probs > 0.5, 1, 0))

output <- cbind(model.df, binary, probs)

fwrite(output,'')