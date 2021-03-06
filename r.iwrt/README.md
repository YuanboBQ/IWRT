# R Package for Data Analysis of the Infant Word Recognition Task (IWRT)

The `r.iwrt` package is used to handle the data exported from the MATLAB task IWRT, which is the master branch in this GitHub repository.

## Installation

### Windows dependencies

If you're on Windows, you might need to install rtools first before you can use the `devtools` package below in Step 1. To install, see here: [http://cran.r-project.org/bin/windows/Rtools/](http://cran.r-project.org/bin/windows/Rtools/)

### Step 1.

First, assuming that both [R](http://www.r-project.org/) and [RStudio](http://www.rstudio.com/) have already been installed and working, open RStudio and then install the package `devtools` from a CRAN server. This is so you can get and build the package from here, GitHub. Copy and paste the following code in the R console:

```r
install.packages("devtools")
```

### Step 2.

Once `devtools` is installed you can now install the `r.iwrt` package. Copy and paste the following code to install this:

```r
devtools::install_github("iamamutt/IWRT/r.iwrt")
```

Or, if you want to also install documentation on how to use this package, run this command instead of the one above. This will build the _vignette_ corresponding to the package. If you just want to browse the documentation online, click the vignette link at the bottom of this page to see the same documentation on GitHub.

```r
# build with vignette
devtools::install_github("iamamutt/IWRT/r.iwrt", build_vignettes=TRUE)

# view vignette
browseVignettes("r.iwrt")
```

## Function Usage

Each time you use the package use must first load it and all its functions by placing the following code at the top of each script.

```r
# load the library
library(r.iwrt)
```

You can now run the automatic processing function by pointing it to the location of your data, then extracting the relevant data components you need for further analysis.

```r
# use the auto function to return important datasets
iwrt_list <- iwrt_auto("path/to/data")

# extract ROI data only
roi <- iwrt_list$roi
```

See more on function usage and data structure here: [Vignette](https://github.com/iamamutt/IWRT/blob/master/r.iwrt/vignettes/main-vignette.Rmd)
