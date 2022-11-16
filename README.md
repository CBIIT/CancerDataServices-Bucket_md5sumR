# CancerDataServices-Bucket_md5sumR
This takes a CDS submission template data file as input that and for any files with missing md5sum values, it will download, calculate md5sum, apply the value and delete the file from the local machine.


To run the script on a complete [CDS v1.3.1 validated submission template](https://github.com/CBIIT/CancerDataServices-SubmissionValidationR), run the following command in a terminal where R is installed for help.

```
Rscript --vanilla CDS-Bucket_md5sumR.R -h
```

```
Usage: CDS-Bucket_md5sumR.R [options]

CDS-Bucket_md5sumR v2.0.0

Options:
	-f CHARACTER, --file=CHARACTER
		CDS submission template dataset file (.xlsx)

	-h, --help
		Show this help message and exit
```
