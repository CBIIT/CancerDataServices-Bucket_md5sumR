#!/usr/bin/env Rscript

#Cancer Data Services - Bucket_md5sumR v2.0.0


##################
#
# USAGE
#
##################

#This takes a CDS submission template data file as input that and for any files with missing md5sum values, it will download, calculate md5sum, apply the value and delete the file from the local machine.

#Run the following command in a terminal where R is installed for help.

#Rscript --vanilla CDS-Bucket_md5sumR.R --help

##################
#
# Env. Setup
#
##################

#List of needed packages
list_of_packages=c("dplyr","readr","stringi","readxl","optparse","tools")

#Based on the packages that are present, install ones that are required.
new.packages <- list_of_packages[!(list_of_packages %in% installed.packages()[,"Package"])]
suppressMessages(if(length(new.packages)) install.packages(new.packages, repos = "http://cran.us.r-project.org"))

#Load libraries.
suppressMessages(library(dplyr,verbose = F))
suppressMessages(library(readr,verbose = F))
suppressMessages(library(stringi,verbose = F))
suppressMessages(library(optparse,verbose = F))
suppressMessages(library(tools,verbose = F))
suppressMessages(library(readxl,verbose = F))


#remove objects that are no longer used.
rm(list_of_packages)
rm(new.packages)


##################
#
# Arg parse
#
##################

#Option list for arg parse
option_list = list(
  make_option(c("-f", "--file"), type="character", default=NULL, 
              help="CDS submission template dataset file (.xlsx)", metavar="character")
)

#create list of options and values for file input
opt_parser = OptionParser(option_list=option_list, description = "\nCDS-Bucket_md5sumR v2.0.0")
opt = parse_args(opt_parser)

#If no options are presented, return --help, stop and print the following message.
if (is.null(opt$file)){
  print_help(opt_parser)
  cat("Please supply an input file (-f).\n\n")
  suppressMessages(stop(call.=FALSE))
}

#Data file pathway
file_path=file_path_as_absolute(opt$file)

#A start message for the user that the validation is underway.
cat("The CDS data template is being examined for files with missing md5sum values.\n\n")


###########
#
# File name rework
#
###########

#Rework the file path to obtain a file name, this will be used for the output file.
file_name=stri_reverse(stri_split_fixed(stri_reverse(basename(file_path)),pattern = ".", n=2)[[1]][2])
ext=tolower(stri_reverse(stri_split_fixed(stri_reverse(basename(file_path)),pattern = ".", n=2)[[1]][1]))
path=paste(dirname(file_path),"/",sep = "")

output_file=paste(file_name,
                  "_md5s",
                  stri_replace_all_fixed(
                    str = Sys.Date(),
                    pattern = "-",
                    replacement = ""),
                  sep="")


#Read in metadata page/file to check against the expected/required properties. 
#Logic has been setup to accept the original XLSX as well as a TSV or CSV format.
if (ext == "tsv"){
  df=suppressMessages(read_tsv(file = file_path, guess_max = 1000000, col_types = cols(.default = col_character())))
}else if (ext == "csv"){
  df=suppressMessages(read_csv(file = file_path, guess_max = 1000000, col_types = cols(.default = col_character())))
}else if (ext == "xlsx"){
  df=suppressMessages(read_xlsx(path = file_path,sheet = "Metadata", guess_max = 1000000, col_types = "text"))
}else{
  stop("\n\nERROR: Please submit a data file that is in either xlsx, tsv or csv format.\n\n")
}


############
#
# Data frame manipulation
#
############

#Create directory to download files in and hide the constantly changing file process.
create_dir=paste(path,"md5sum_calc/",sep = "")
dir.create(path = create_dir,showWarnings = F)

#Split the manifest into files with md5sums and without md5sums. The without section will move forward in the script.
df_no_md5=df[is.na(df$md5sum),]
df_md5=df[!is.na(df$md5sum),]

#If full file path is in the url
for (bucket_loc in 1:dim(df_no_md5)[1]){
  bucket_url=df_no_md5$file_url_in_cds[bucket_loc]
  bucket_file=df_no_md5$file_name[bucket_loc]
  #skip if bucket_url is NA (no associated url for file)
  if (!is.na(bucket_url)){
    #see if the file name is found in the bucket_url
    if (grepl(pattern = bucket_file,x = bucket_url)){
      #download file, run md5sum, copy to data frame and delete file
      dl_file_name=basename(bucket_url)
      system(command = paste("aws s3 cp ",bucket_url," ",create_dir, sep = ""),intern = T)
      file_md5=md5sum(files = paste(create_dir,dl_file_name,sep = ""))
      df_no_md5$md5sum[bucket_loc]=file_md5
      system(command = paste("rm ",create_dir,dl_file_name,sep = ""))
    }
    #if the file url has to be reworked to include the file with the base directory.
    else{
      if (substr(bucket_url,start = nchar(bucket_url),stop = nchar(bucket_url))=="/"){
        #fix the 'file_url_in_cds' section to have the full file location
        bucket_url=paste(bucket_url,bucket_file,sep = "")
        df_no_md5$file_url_in_cds[bucket_loc]=bucket_url
        #download file, run md5sum, copy to data frame and delete file
        dl_file_name=basename(bucket_url)
        system(command = paste("aws s3 cp ",bucket_url," ",create_dir, sep = ""),intern = T)
        file_md5=md5sum(files = paste(create_dir,dl_file_name,sep = ""))
        df_no_md5$md5sum[bucket_loc]=file_md5
        system(command = paste("rm ",create_dir,dl_file_name,sep = ""))
      }else{
        #fix the 'file_url_in_cds' section to have the full file location
        bucket_url=paste(bucket_url,"/",bucket_file,sep = "")
        df_no_md5$file_url_in_cds[bucket_loc]=bucket_url
        #download file, run md5sum, copy to data frame and delete file
        dl_file_name=basename(bucket_url)
        system(command = paste("aws s3 cp ",bucket_url," ",create_dir, sep = ""),intern = T)
        file_md5=md5sum(files = paste(create_dir,dl_file_name,sep = ""))
        df_no_md5$md5sum[bucket_loc]=file_md5
        system(command = paste("rm ",create_dir,dl_file_name,sep = ""))
      }
    }
  }
}

#Add the files with newly acquired md5sum section back onto the other data frame of files that already had md5sums.
df_all=rbind(df_md5,df_no_md5)

#Write out manifest.
write_tsv(x = df_all, file = paste(path,output_file,".tsv",sep = ""), na="")

#Delete created directory
unlink(create_dir, recursive = TRUE)

cat(paste("\n\nProcess Complete.\n\nThe output file can be found here: ",path,"\n\n",sep = "")) 
