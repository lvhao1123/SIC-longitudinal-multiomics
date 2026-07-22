# Data access and redistribution restrictions

## Source data

The clinical, transcriptomic and proteomic participant-level data used by this project originate from OMIX011182. They are available only after formal approval by the National Genomics Data Center:

<https://ngdc.cncb.ac.cn/omix/release/OMIX011182>

The project authors cannot redistribute these controlled files through GitHub, manuscript supplementary files or public source-data packages.

## Local authorised execution

After approval, place the controlled files outside the Git repository and set `CMAISE_DATA_DIR` to the authorised local directory. Generated participant-level intermediates must remain under ignored `private_outputs/` or `private_audit/` paths.

## Materials that may be shared

Repository code, aggregate non-identifiable result tables, figure source data that pass privacy QA, software-environment records and manuscript-support documents may be shared. Public files must not contain `PatientID`, traceable `SampleName`, individual sampling probabilities or individual inverse-probability weights.

Access restrictions do not prevent computational reproducibility: the repository records the input contract, verified code provenance, software environment, deterministic seeds, aggregate numeric truth and data-free QA. Full numerical reruns require separately authorised source data.
