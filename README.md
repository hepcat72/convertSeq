# convertSeq

Convert between different DNA/RNA sequence formats.

## WHAT IS THIS:

This script will convert to and from these sequence file formats: fastq, Illumina's qseq format, and fasta (both sequence and quality files).  You can output to multiple file formats at the same time by providing mulitple output file suffixes.  Also, it will convert between quality formats phred33 (i.e. sanger quality) and phred64 (solexa quality).

## INSTALLATION

    perl Makefile.PL
    make
    sudo make install

## USAGE

By example:

    convertSeq.pl -i input.fq --fasta-seq-suffix .fa --from-fastq --to-fasta

Command line interface:

    INPUT FILE OPTIONS
    
     -i|--seq-file*       REQUIRED Space-separated sequence file(s inside
                                   quotes).  Standard input via redirection is
                                   acceptable.  Perl glob characters (e.g. '*')
                                   are acceptable inside quotes (e.g.
                                   -i "*.txt *.text").  See --help for a
                                   description of the input file format.
                                   Acceptable file formats are fasta, fastq,
                                   and qseq/solexa.  Any file extension may
                                   be used as long as it is a text/ascii-based
                                   file.  *No flag required.
     -t|--qual-file       OPTIONAL [none] Space-separated fasta quality file(s
                                   inside quotes).  Standard input via
                                   redirection is acceptable.  Perl glob
                                   characters (e.g. '*') are acceptable inside
                                   quotes (e.g. -i "*.txt *.text").  See --help
                                   for a description of the input file format.
                                   Any file extension may  be used as long as
                                   it is a text/ascii-based file.
    
    OUTPUT FILE OPTIONS
    
     --fasta-seq-suffix   OPTIONAL [nothing] This suffix is added to the input
                                   file names to use as output files.
                                   Redirecting a file into this script will
                                   result in the output file name to be "STDIN"
                                   with your suffix appended.  See --help for a
                                   description of the output file format.
                                   Supplying this option automatically turns on
                                   the -f flag.
     --fasta-qual-suffix  OPTIONAL [nothing] This suffix is added to the input
                                   file names to use as output files.
                                   Redirecting a file into this script will
                                   result in the output file name to be "STDIN"
                                   with your suffix appended.  See --help for a
                                   description of the output file format.
                                   Supplying this option automatically turns on
                                   the -f flag.
     --fastq-suffix       OPTIONAL [nothing] This suffix is added to the input
                                   file names to use as output files.
                                   Redirecting a file into this script will
                                   result in the output file name to be "STDIN"
                                   with your suffix appended.  See --help for a
                                   description of the output file format.
                                   Supplying this option automatically turns on
                                   the -q flag.
     --qseq-suffix        OPTIONAL [nothing] This suffix is added to the input
        --solexa-suffix            file names to use as output files.
                                   Redirecting a file into this script will
                                   result in the output file name to be "STDIN"
                                   with your suffix appended.  See --help for a
                                   description of the output file format.
                                   Supplying this option automatically turns on
                                   the -s flag.
     --show-quality-      OPTIONAL [Off] Show the different types of quality
       conversion                  scores on standard output and exit.  Not
                                   compatible with any other option.
    
    INPUT FORMAT OPTIONS
    
     --from-fasta         OPTIONAL [Off] Force input to be read as fasta
                                   format.  Default: automatic format
                                   detection.  Incompatible with --from-fastq
                                   and --from-qseq.
     --from-fastq         OPTIONAL [Off] Force input to be read as fastq
                                   format.  Default: automatic format
                                   detection.  Incompatible with --from-fasta
                                   and --from-qseq.
     --from-qseq          OPTIONAL [Off] Force input to be read as qseq/
        --from-solexa              solexa format.  Default: automatic format
                                   detection.  Incompatible with --from-fasta
                                   and --from-fastq.
     --skip-format-check  OPTIONAL [Off] The quality formats are very similar,
                                   so double-checking the format can take a
                                   good bit of time.  If you'd like to skip
                                   this time-consuming check, supply this
                                   option and specify the file (--from-fasta,
                                   --from-fastq, --from-qseq) and quality
                                   (--from-illunima-qual or --from-sanger-qual)
                                   input formats.  You must supply one of each
                                   of these format types in order to skip the
                                   format-check.
     --ignore-extra-      OPTIONAL [Off] Do not issue an error if there are
       qualities                   more records in the quality files than there
                                   are in the sequence files.
    
    OUTPUT FORMAT OPTIONS
    
     --to-fasta           OPTIONAL [Off] Output in fasta format.  May be used
                                   with -q and -s to output in multiple
                                   formats.  See the output suffix options
                                   below.
     --to-fastq           OPTIONAL [Off] Output in fastq format.  May be used
                                   with -f and -s to output in multiple
                                   formats.  See the output suffix options
                                   below.
     --to-qseq            OPTIONAL [Off] Output in qseq/solexa format.  May
        --to-solexa                be used with -f and -q to output in multiple
                                   formats.  See the output suffix options
                                   below.

    ADVANCED FORMAT OPTIONS
    
     --from-solexa-qual   OPTIONAL [Off] Force input quality scores to be
        --from-phred64             treated as qseq/solexa/phred64 scores.
                                   Defaults to true if --from-qseq is supplied.
                                   Incompatible with --from-sanger-qual.
     --from-sanger-qual   OPTIONAL [Off] Force input quality scores to be
        --from-phred33             treated as sanger/phred33 scores.  Defaults
                                   to true if --from-fasta or --from-fastq is
                                   supplied.  Incompatible with
                                   --from-solexa-qual.
     --to-solexa-qual     OPTIONAL [Off] Output quality scores using solexa
        --to-phred64               logic.  Defaults to true for qseq format and
                                   false for fasta and fastq formats.
                                   Incompatible with --to-sanger-qual.
     --to-sanger-qual     OPTIONAL [Off] Output quality scores using sanger
        --to-phred33               logic.  Defaults to false for qseq format
                                   and true for fasta and fastq formats.
                                   Incompatible with --to-solexa-qual.
     --quality-terminator OPTIONAL [none] For use with the -q and/or
                                   --fastq-suffix options.  When a character
                                   string is supplied to this option, it will
                                   be appended to the end of the quality string
                                   in each record.  Note, some formats use the
                                   exclamation point (!) to terminate the
                                   quality string.
    
    DEFAULT OPTIONS
    
     --force|--overwrite  OPTIONAL Force overwrite of existing output files.
                                   Only used when the -o option is supplied.
     --ignore             OPTIONAL Ignore critical errors & continue
                                   processing.  (Errors will still be
                                   reported.)  See --force to not exit when
                                   existing output files are found.
     --verbose            OPTIONAL Verbose mode.  Cannot be used with the quiet
                                   flag.  Verbosity level can be increased by
                                   supplying a number (e.g. --verbose 2) or by
                                   supplying the --verbose flag multiple times.
     --quiet              OPTIONAL Quiet mode.  Suppresses warnings and errors.
                                   Cannot be used with the verbose or debug
                                   flags.
     --help|-?            OPTIONAL Help.  Print an explanation of the script
                                   and its input/output files.
     --version            OPTIONAL Print software version number.  If verbose
                                   mode is on, it also prints the template
                                   version used to standard error.
     --debug              OPTIONAL Debug mode.  Adds debug output to STDERR and
                                   prepends trace information to warning and
                                   error messages.  Cannot be used with the
                                   --quiet flag.  Debug level can be increased
                                   by supplying a number (e.g. --debug 2) or by
                                   supplying the --debug flag multiple times.
     --noheader           OPTIONAL Suppress commented header output.  Without
                                   this option, the script version, date/time,
                                   and command-line information will be printed
                                   at the top of all output files commented
                                   with '#' characters.

## FASTA SEQUENCE FORMAT EXAMPLE:

    #comment about file
    >sequence1
    CTGATCGTGCTAGCTGTCGTAGTCG
    CGTAGCGTCGTAGCGT
    >sequence2
    GCTATGCGGCTGATGCGCGTAGCGG
    GTGTCGTAT

## FASTA QUALITY FORMAT EXAMPLE:

    #comment about file
    >sequence1
    0 0 0 20 21 30 40 40 40 40 40 40 40 40 40 40 40 40 40 40 40 40 40 40 40
    33 29 27 19 10 5 0 0 0 0 0 0 0 0 0 0
    >sequence2
    0 0 0 20 21 30 40 40 40 40 40 40 40 40 33 40 40 40 40 40 40 40 40 40 40
    20 20 10 10 0 0 0 0 0

## FASTQ FORMAT EXAMPLE:

    #comment about file
    @HWUSI-EAS1520:1:1:19704:5707#0/1
    AAGAAAACATGAAGTATGGACATATCTTGAATGAGTTCTTTGAACAAAAAGTTGAAGAAACACTTAGATCGGAAGA
    +HWUSI-EAS1520:1:1:19704:5707#0/1
    ^Y\bZ`VR``VU^VP^ZZXZXZXX[bZ\ZbZZX^ZXaT\aVQJ\Vbb\YTPUVZVb\Z]ZU\L`BBBBBBBBBBBB
    @HWUSI-EAS1520:1:1:19704:17742#0/1
    AGCGTGAAGTTTATCAACATTATGCCTTAAGTGCATTACCATTTCCAGAAAAAACAAAATTTGAAAAGATCGGAAG
    +HWUSI-EAS1520:1:1:19704:17742#0/1
    M\T\]QTUUUYU\^]T^`]Z]^\`Y^```]ba`aaYW\\TaT\YYRRRQQ]ZZ`YW\`\Y]]ZUb]_]\ZZXSZ`c

## QSEQ/SOLEXA FORMAT EXAMPLE:

    #comment about file
    HWUSI-EAS1520	0001	1	1	1046	13781	0	1	TTTCCTAACAGCACATTCTCAATCATTTCCGTAGTCCTTAACTTCGACCTAACCAAGATCCATGATCACTTCTGCT	BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB	0
    HWUSI-EAS1520	0001	1	1	1046	4538	0	1	GAACATTGTGATTTCTTTGGTTTTGGAACTAATGATTTTAGGCGATTAGCATATGGTTTTCCACGTGTTGATGCAA	T`YLLbb\b^cccTLLbQG_`]```M\]^ZLL^T]^bbLKLaJLPaT`YTKQQW]aXJJJVb\bb]KKZ_VS]_^^	0
