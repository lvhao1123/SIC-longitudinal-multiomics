# Run from the package root in a fresh RStudio session:
# source("plotting/run_all_figures.R")
# Or: Rscript --vanilla plotting/run_all_figures.R NEW_OUTPUT_DIRECTORY
local({
  a <- commandArgs(trailingOnly=TRUE)
  root <- normalizePath(getwd(), winslash="/", mustWork=TRUE)
  stopifnot(file.exists(file.path(root,"plotting/FIGURE_CODE_DATA_INDEX.tsv")))
  out <- if(length(a)) a[1] else file.path(root,"figure_output")
  if(file.exists(out)) stop("Use a new output directory; existing output is never overwritten.")
  dir.create(out,recursive=TRUE)
  out <- normalizePath(out,winslash="/",mustWork=TRUE)
  p <- file.path(root,"plotting")
  for(d in c("R","qa","figures","private","logs","environment")) dir.create(file.path(out,d))
  file.copy(list.files(file.path(p,"R"),pattern="\\.R$",full.names=TRUE),file.path(out,"R"))
  file.copy(file.path(p,"qa/FIGURE_SIZE_MAP.tsv"),file.path(out,"qa/FIGURE_SIZE_MAP.tsv"))
  required <- c("data.table","dplyr","tidyr","stringr","ggplot2","patchwork","svglite","ragg","jsonlite")
  missing <- required[!vapply(required,requireNamespace,logical(1),quietly=TRUE)]
  if(length(missing)) stop("Missing declared packages: ",paste(missing,collapse=", "),". Install in a project library; no automatic installation is performed.")
  write.table(data.frame(package=required,version=vapply(required,function(x)as.character(packageVersion(x)),character(1))),file.path(out,"environment/package_versions.tsv"),sep="\t",row.names=FALSE,quote=FALSE)
  capture.output(sessionInfo(),file=file.path(out,"environment/sessionInfo.txt"))
  env <- c(SIC_PLOT_ROOT=out,SIC_R7_BASE=file.path(p,"data"),SIC_PROJECT_DIR=file.path(p,"data"),SIC_FIGURE_OUTPUT=out,SIC_CENTRE_FIG_OUTPUT=out,SIC_PROFILE="candidate",SIC_FONT_PT="7.25",SIC_CLINICAL_COX_FILE=file.path(p,"data/figure_source_data/SourceData_Supplementary_Figure_A9.tsv"))
  old <- Sys.getenv(names(env),unset=NA_character_)
  on.exit({for(i in seq_along(old)) if(is.na(old[i])) Sys.unsetenv(names(env)[i]) else do.call(Sys.setenv,setNames(list(old[i]),names(env)[i]))},add=TRUE)
  do.call(Sys.setenv,as.list(env))
  rs <- file.path(R.home("bin"),"Rscript.exe")
  scripts <- c(sort(list.files(file.path(p,"R"),pattern="^0.*\\.R$")),"render_S3_labels.R")
  records <- list()
  for(s in scripts) {
    args <- if(s=="07_S15.R") c(file.path(p,"data/source_data"),out) else if(s=="render_S3_labels.R") c(out,out) else c("--project",file.path(p,"data"),"--output",out)
    cmd <- c("--vanilla",file.path(out,"R",s),args)
    log <- file.path(out,"logs",paste0(s,".log"));cat("Running ",s,"\n",sep="")
    started <- Sys.time();status <- system2(rs,shQuote(cmd),stdout=log,stderr=log)
    records[[s]] <- data.frame(script=s,exit_status=status,seconds=as.numeric(difftime(Sys.time(),started,units="secs")),command=paste(shQuote(c(rs,cmd)),collapse=" "))
    write.table(do.call(rbind,records),file.path(out,"EXECUTION.tsv"),sep="\t",row.names=FALSE,quote=TRUE)
  }
  index <- read.delim(file.path(p,"FIGURE_CODE_DATA_INDEX.tsv"),check.names=FALSE)
  for(i in seq_len(nrow(index))) {
    oldname <- index$prior_output_stem[i];newname <- index$figure[i]
    if(oldname!=newname && !grepl("^A3_part_",oldname)) for(ext in c("svg","pdf","tiff","png")) {
      src<-file.path(out,"figures",paste0(oldname,".",ext));if(file.exists(src)) file.copy(src,file.path(out,"figures",paste0(newname,".",ext)))
    }
  }
  if(any(vapply(records,function(x)x$exit_status!=0,logical(1)))) stop("One or more plotting scripts failed. See EXECUTION.tsv and logs.")
  cat("All drawing scripts completed. Numeric and visual acceptance must be checked separately.\n")
})
