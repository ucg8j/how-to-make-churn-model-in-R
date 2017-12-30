# How to Make a Churn Model in R #

For further context behind this repo please read this [blog post](https://lukesingham.com/how-to-make-a-churn-model-in-r/).

## Repo Contents ##
```
├── DataScienceTakeHomeTest_(3).pdf 	# Take home Provided by company
├── Report.Rmd                          # R markdown 
├── Report.html                         # The report/output from Report.Rmd
├── Run.R                               # Wrapper script
├── model.rda                           # Saved model
└── monthly_data_(2)_(2).csv            # Provided by company
```

The main document and reasoning behind the model can be found in Report.html. If you would like to run the model over the data, I’ve copied the code developed in the report into a script that will provide the model outputs into a csv, running the following from a *nix terminal:
```
cat monthly_data_(2)_(2).csv | Rscript Run.R >| churns.csv
```
