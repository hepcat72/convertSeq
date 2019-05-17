#!/usr/bin/perl -w

#Generated using perl_script_template.pl 1.40
#Robert W. Leach
#rwleach@ccr.buffalo.edu
#Center for Computational Research
#Copyright 2010


##
## Library Inclusions
##


use strict;
use Getopt::Long;


##
## Variable Declarations & default values
##


#These variables (in main) are used by getVersion() and usage()
my $software_version_number        = '1.5';
my $created_on_date                = '5/26/2010';

#Basic interface variables
my $help                           = 0;
my $version                        = 0;
my $overwrite                      = 0;
my $noheader                       = 0;

#Outfile suffix variables not defined so a user can overwrite the input file
my($fasta_qual_suffix,$fasta_seq_suffix,$fastq_suffix,$qseq_suffix);
my @seq_files                      = ();
my @qual_files                     = ();
my $current_output_fasta_seq_file  = '';
my $current_output_fasta_qual_file = '';
my $current_output_fastq_file      = '';
my $current_output_qseq_file       = '';

#Specification of input formats
my $from_fasta                     = 0;
my $from_fastq                     = 0;
my $from_qseq                      = 0;
my $from_phred33                   = 0;
my $from_phred64                   = 0;
my $skip_format_check              = 0;
my $ignore_extra_quals             = 0;

#Specification of output formats
my $test_qualities                 = 0;
my $to_fasta                       = 0;
my $to_fastq                       = 0;
my $to_qseq                        = 0;
my $to_phred64                     = 0;
my $to_phred33                     = 0;
my $no_qual_defline                = 0;
my $quality_terminator             = ''; #Some formats use an '!'

#These variables (in main) are used by the following subroutines:
#verbose, error, warning, debug, getCommand, quit, and usage
my $preserve_args = [@ARGV];  #Preserve the agruments for getCommand
my $verbose       = 0;
my $quiet         = 0;
my $DEBUG         = 0;
my $ignore_errors = 0;

#Command Line Options
my $GetOptHash =
  {#INPUT FILES
   'i|seq-file=s'           => sub {push(@seq_files,       #REQUIRED unless <>
				         sglob($_[1]))},   #         supplied
   '<>'                     => sub {push(@seq_files,       #REQUIRED unless -i
					 sglob($_[0]))},   #         supplied
   't|qual-file=s'          => sub {push(@qual_files,      #OPTIONAL [none] See
				         sglob($_[1]))},   # usage for reqrmnts
   'show-quality-conversion!'      => \$test_qualities,    #OPTIONAL [Off]

   #INPUT FILE FORMAT SPECIFICATIONS
   'from-fasta!'                   => \$from_fasta,        #OPTIONAL [Off]
   'from-fastq!'                   => \$from_fastq,        #OPTIONAL [Off]
   'from-qseq|from-solexa!'        => \$from_qseq,         #OPTIONAL [Off]
   'from-solexa-qual|from-phred64!'=> \$from_phred64,      #OPTIONAL [Off]
   'from-sanger-qual|from-phred33!'=> \$from_phred33,      #OPTIONAL [Off]
   'skip-format-check!'            => \$skip_format_check, #OPTIONAL [Off]
   'ignore-extra-qualities!'       => \$ignore_extra_quals,#OPTIONAL [Off]

   #OUTPUT FORMATS
   'f|to-fasta!'                   => \$to_fasta,          #OPTIONAL [Off]
   'q|to-fastq!'                   => \$to_fastq,          #OPTIONAL [Off]
   's|to-qseq|to-solexa!'          => \$to_qseq,           #OPTIONAL [Off]
   'to-solexa-qual|to-phred64!'    => \$to_phred64,        #OPTIONAL [Off]
   'to-sanger-qual|to-phred33!'    => \$to_phred33,        #OPTIONAL [Off]
   'quality-terminator=s'          => \$quality_terminator,#OPTIONAL [none]
   'no-fastq-qual-defline!'        => \$no_qual_defline,   #OPTIONAL [Off]

   #OUTPUT FILE SUFFIXES
   'fasta-qual-suffix=s'           => \$fasta_qual_suffix, #OPTIONAL [none]
   'fasta-seq-suffix=s'            => \$fasta_seq_suffix,  #OPTIONAL [none]
   'fastq-suffix=s'                => \$fastq_suffix,      #OPTIONAL [none]
   'qseq-suffix|solexa-suffix=s'   => \$qseq_suffix,       #OPTIONAL [none]

   #BASIC OPTIONS
   'force|overwrite'               => \$overwrite,         #OPTIONAL [Off]
   'ignore'                        => \$ignore_errors,     #OPTIONAL [Off]
   'verbose:+'                     => \$verbose,           #OPTIONAL [Off]
   'quiet'                         => \$quiet,             #OPTIONAL [Off]
   'debug:+'                       => \$DEBUG,             #OPTIONAL [Off]
   'help|?'                        => \$help,              #OPTIONAL [Off]
   'version'                       => \$version,           #OPTIONAL [Off]
   'noheader|no-header'            => \$noheader,          #OPTIONAL [Off]
  };


##
## Input Validation
##


#If there are no arguments and no files directed or piped in
if(scalar(@ARGV) == 0 && isStandardInputFromTerminal())
  {
    usage();
    quit(0);
  }

#Get the input options & catch any errors in option parsing
unless(GetOptions(%$GetOptHash))
  {
    #Try to guess which arguments GetOptions is complaining about
    my @possibly_bad = grep {!(-e $_)} @seq_files;

    error('Getopt::Long::GetOptions reported an error while parsing the ',
	  'command line arguments.  The error should be above.  Please ',
	  'correct the offending argument(s) and try again.');
    usage(1);
    quit(-1);
  }

#Print the debug mode (it checks the value of the DEBUG global variable)
debug('Debug mode on.') if($DEBUG > 1);

debug("There were [",scalar(@qual_files),"] quality files.");

#If the user has asked for help, call the help subroutine
if($help)
  {
    help();
    quit(0);
  }

#If the user has asked for the software version, print it
if($version)
  {
    print(getVersion($verbose),"\n");
    quit(0);
  }

#Check validity of verbosity options
if($quiet && ($verbose || $DEBUG))
  {
    $quiet = 0;
    error('You cannot supply the quiet and (verbose or debug) flags ',
	  'together.');
    quit(-2);
  }

#Put standard input into the seq_files array if standard input has been redirected in
if(!isStandardInputFromTerminal())
  {
    push(@seq_files,'-');

    #Warn the user about the naming of the outfile when using STDIN
    if(defined($fasta_seq_suffix) || defined($fasta_qual_suffix) ||
       defined($fastq_suffix) || defined($qseq_suffix))
      {warning('Input on STDIN detected along with an outfile suffix.  The ',
	       'name of your output files will start with STDIN.')}
    #Warn users when they turn on verbose and output is to the terminal
    #(implied by no outfile suffix checked above) that verbose messages may be
    #uncleanly overwritten
    elsif($verbose && isStandardOutputToTerminal())
      {warning('You have enabled --verbose, but appear to possibly be ',
	       'outputting to the terminal.  Note that verbose messages can ',
	       'interfere with formatting of terminal output making it ',
	       'difficult to read.  You may want to either turn verbose off, ',
	       'redirect output to a file, or supply an outfile suffix (-o).')}
  }

#Make sure there is input
if(scalar(@seq_files) == 0 && !$test_qualities)
  {
    error('No input files detected.');
    usage(1);
    quit(-3);
  }

#Turn on the fasta flag if either of the fasta suffixes was supplied
if((defined($fasta_qual_suffix) && $fasta_qual_suffix ne '') ||
   (defined($fasta_seq_suffix)  && $fasta_seq_suffix ne ''))
  {$to_fasta = 1}

#Turn on the fastq flag if the fastq suffix was supplied
if(defined($fastq_suffix) && $fastq_suffix ne '')
  {$to_fastq = 1}

#Turn on the qseq flag if the qseq suffix was supplied
if(defined($qseq_suffix) && $qseq_suffix ne '')
  {$to_qseq = 1}

#If multiple formats are being output, the fasta flag is true, and no fasta
#suffix has been defined
if($to_fasta + $to_fastq + $to_qseq > 1 && $to_fasta &&
   ((!defined($fasta_qual_suffix) || $fasta_qual_suffix eq '') &&
    (!defined($fasta_seq_suffix)  || $fasta_seq_suffix eq '')))
  {
    error("A fasta format suffix (--fasta-seq-suffix or --fasta-qual-suffix) ",
	  "is required when outputting multiple sequence formats (i.e. when ",
	  "2 or more of these flags are true: --fasta, --fastq, --qseq).");
    quit(1);
  }

#If multiple formats are being output, the fastq flag is true, and no fastq
#suffix has been defined
if($to_fasta + $to_fastq + $to_qseq > 1 && $to_fastq &&
   (!defined($fastq_suffix) || $fastq_suffix eq ''))
  {
    error("The fastq format suffix (--fastq-suffix) is required when ",
	  "outputting multiple sequence formats (i.e. when 2 or more of ",
	  "these flags are true: --fasta, --fastq, --qseq).");
    quit(2);
  }

#If multiple formats are being output, the qseq flag is true, and no qseq
#suffix has been defined
if($to_fasta + $to_fastq + $to_qseq > 1 && $to_qseq &&
   (!defined($qseq_suffix) || $qseq_suffix eq ''))
  {
    error("The qseq format suffix (--qseq-suffix) is required when --to-qseq ",
	  "is supplied among multiple sequence output formats (i.e. when 2 ",
	  "or more of these flags are true: --fasta, --fastq, --qseq).");
    quit(3);
  }

if(scalar(@qual_files) && scalar(@seq_files) != scalar(@qual_files))
  {
    error("The number of quality files: [",scalar(@qual_files),"] must equal ",
	  "the number of sequence files: [",scalar(@seq_files),"].");
    quit(4);
  }

#Error check the input format specified
if($from_fasta + $from_fastq + $from_qseq > 1)
  {
    error("Multiple input formats specified.  Only one of these flags is ",
	  "allowed: [--from-fasta, --from-fastq, or --form-qseq].");
    quit(5);
  }

#Error check the input quality format specified
if($from_phred64 && $from_phred33)
  {
    error("Multiple input quality formats specified.  Only one of these ",
	  "flags is allowed: [--from-solexa-qual or --from-sanger-qual].");
    quit(6);
  }

#Make sure from_fasta is true if quality files were supplied
if(!$from_fasta && scalar(@qual_files))
  {
    $from_fasta = 1;
    $from_fastq = 0;
    $from_qseq  = 0;
  }
elsif($from_fasta && ($to_fastq || $to_qseq) && scalar(@qual_files) == 0)
  {
    error("To input in fasta format and output in fastq or qseq format, you ",
	  "must supply quality files using --qual-files.");
    quit(7);
  }

#Check the validity of the quality format option combinations
if($to_phred64 && $to_phred33)
  {
    error("--to-solexa-qual and --to-sanger-qual options are not compatible ",
	  "together.  Please specify only one.");
    quit(8);
  }
if($quality_terminator ne '' && !$to_fastq)
  {
    warning("--quality-terminator: [$quality_terminator] is only used for ",
	    "--to-fastq mode.  This variable will be ignored.");
  }

#Fasta and Fastq are typically phred33, so set it for them if they did not
#specify a quality format
if(($to_fasta || $to_fastq) && !$to_qseq && !$to_phred33 && !$to_phred64)
  {$to_phred33 = 1}
elsif($to_qseq && !$to_fasta && !$to_fastq && !$to_phred33 && !$to_phred64)
  {$to_phred64 = 1}
if(($from_fasta || $from_fastq) && !$from_qseq && !$from_phred33 &&
   !$from_phred64)
  {$from_phred33 = 1}
elsif($from_qseq && !$from_fasta && !$from_fastq && !$from_phred33 &&
      !$from_phred64)
  {$from_phred64 = 1}

#I don't believe I need to check quality format because of the default behavior
#I added based on the file format chosen.  Still need to check file format
#though.
#if($skip_format_check && (($from_phred64 + $from_phred33 == 0) ||
#			  ($from_fasta + $from_fastq + $from_qseq == 0)))
if($skip_format_check && ($from_fasta + $from_fastq + $from_qseq == 0))
  {
    error("If --skip-format-check is supplied, you must specify a quality ",
	  "format (--from-solexa-qual, --from-phred64, --from-sanger-qual, ",
	  "or --from-phred33) and a file format (--from-fasta, --from-fastq, ",
	  "--from-solexa, or --from-qseq).");
    quit(9);
  }

#Check to make sure previously generated output files won't be over-written
#Note, this does not account for output redirected on the command line
if(!$overwrite && (defined($fasta_seq_suffix) || defined($fasta_qual_suffix) ||
		   defined($fastq_suffix) || defined($qseq_suffix)))
  {
    my $existing_outfiles = [];
    foreach my $infile (@seq_files)
      {
	my $output_file = '';
	if(defined($fasta_seq_suffix))
	  {
	    $output_file = ($infile eq '-' ? 'STDIN' : $infile) .
	      $fasta_seq_suffix;
	    push(@$existing_outfiles,$output_file) if(-e $output_file);
	  }
	if(defined($fasta_qual_suffix))
	  {
	    $output_file = ($infile eq '-' ? 'STDIN' : $infile) .
	      $fasta_qual_suffix;
	    push(@$existing_outfiles,$output_file) if(-e $output_file);
	  }
	if(defined($fastq_suffix))
	  {
	    $output_file = ($infile eq '-' ? 'STDIN' : $infile) .
	      $fastq_suffix;
	    push(@$existing_outfiles,$output_file) if(-e $output_file);
	  }
	if(defined($qseq_suffix))
	  {
	    $output_file = ($infile eq '-' ? 'STDIN' : $infile) .
	      $qseq_suffix;
	    push(@$existing_outfiles,$output_file) if(-e $output_file);
	  }
      }

    if(scalar(@$existing_outfiles))
      {
	error("The output files: [@$existing_outfiles] already exist.  ",
	      'Use --overwrite to force an overwrite of existing files.  ',
	      "E.g.:\n",getCommand(1),' --overwrite');
	quit(-4);
      }
  }

#If they want to show the quality conversion, print a message showing the
#corresponding values
if($test_qualities)
  {
    my $sanger_qual_str       = join('',map {chr($_ + 33)} 1..40);
    my $solexa_qual_str       = join('',map {chr($_ + 64)} -5..40);
    my $fasta_sanger_qual_str = join(' ',1..40);
    my $fasta_solexa_qual_str = join(' ',-5..40);

    print("\nThe following quality mappings are based on the information and ",
	  "data found on the following websites:\n\n\t",
	  "http://maq.sourceforge.net/fastq.shtml\n\t",
	  "http://maq.sourceforge.net/qual.shtml\n\t",
	  "http://en.wikipedia.org/wiki/FASTQ_format\n\n",
	  "Note that only the common values are shown below.  Values can be ",
	  "larger for contigs/assemblies, but sequencers should not output ",
	  "anything larger than what's shown here.\n\n",

	  "Sanger Values (uncompressed and compressed):\n\n",
	  join(' ',
	       map {length($_) == 1 ? " $_" : $_}
	       split(/ +/,$fasta_sanger_qual_str)),
	  "\n",
	  join(' ',map {" $_"} unpack('A1' x length($sanger_qual_str),
				      $sanger_qual_str)),
	  "\n\n",
	  "Solexa Values (uncompressed and compressed):\n\n",
	  join(' ',
	       map {length($_) == 1 ? " $_" : $_}
	       split(/ +/,$fasta_solexa_qual_str)),
	  "\n",
	  join(' ',map {" $_"} unpack('A1' x length($solexa_qual_str),
				      $solexa_qual_str)),
	  "\n\n");

    my $new_solexa_qual_str = compressedPhred33toPhred64($sanger_qual_str);
    my $new_fasta_solexa_qual_str =
      uncompressedPhred33toPhred64($fasta_sanger_qual_str);
    my $new_sanger_qual_str = compressedPhred64toPhred33($solexa_qual_str);
    my $new_fasta_sanger_qual_str =
      uncompressedPhred64toPhred33($fasta_solexa_qual_str);

    print("Converting between the two versions is not a one-to-one ",
	  "conversion.  Some Solexa values map to the same Sanger value, ",
	  "thus if you convert from Solexa to Sanger and back to Solexa, ",
	  "some values may not match.  Below is what you get converting to ",
	  "and from each Sanger and Solexa quality value (based on the ",
	  "conversion equation found on the maq website linked above:\n\n",

	  "Sanger     ",join(' ',
			     map {length($_) == 1 ? " $_" : $_}
			     split(/ +/,$fasta_sanger_qual_str)),"\n",
	  "           ",join(' ',
			     map {" $_"}
			     unpack('A1' x length($sanger_qual_str),
				    $sanger_qual_str)),"\n",
	  "to Solexa  ",join(' ',
			     map {" $_"}
			     unpack('A1' x length($new_solexa_qual_str),
				    $new_solexa_qual_str)),"\n",
	  "           ",join(' ',
			     map {length($_) == 1 ? " $_" : $_}
			     split(/ +/,$new_fasta_solexa_qual_str)),"\n\n",

	  "Solexa     ",join(' ',
			     map {length($_) == 1 ? " $_" : $_}
			     split(/ +/,$fasta_solexa_qual_str)),"\n",
	  "           ",join(' ',
			     map {" $_"}
			     unpack('A1' x length($solexa_qual_str),
				    $solexa_qual_str)),"\n",
	  "to Sanger  ",join(' ',
			     map {" $_"}
			     unpack('A1' x length($new_sanger_qual_str),
				    $new_sanger_qual_str)),"\n",
	  "           ",join(' ',
			     map {length($_) == 1 ? " $_" : $_}
			     split(/ +/,$new_fasta_sanger_qual_str)),"\n\n",

	  "Note that you can explicitly specify the to- and from- quality ",
	  "formats on the command line (see usage output by running without ",
	  "any input options).  Otherwise, the quality format will be ",
	  "assumed to be solexa (i.e. phred64) if the solexa file format is ",
	  "specified and sanger (i.e. phred33) if fasta or fastq is ",
	  "specified.\n\n");

    quit(0);
  }

verbose('Run conditions: ',getCommand(1));


##
## Start Main
##


#If output is going to STDOUT instead of output files with different extensions
#or if STDOUT was redirected, output run info once
verbose('[STDOUT] Opened for all output.')
  if(((!defined($fasta_seq_suffix) || !defined($fasta_qual_suffix)) &&
      $to_fasta) ||
     (!defined($fastq_suffix) && $to_fastq) ||
     (!defined($qseq_suffix) && $to_qseq));

#Store info. about the run as a comment at the top of the output file if
#STDOUT has been redirected to a file
if(!isStandardOutputToTerminal() && !$noheader)
  {print('#',join("\n#",split(/\n/,getVersion())),"\n",
	 '#',scalar(localtime($^T)),"\n",
	 '#',getCommand(1),"\n");}

my $global_file_format  = ($from_fasta ? 'fasta' :
			   ($from_fastq ? 'fastq' :
			    ($from_qseq ? 'qseq' : '')));
my $global_qual_format  = ($from_phred64 ? 'phred64' :
			   ($from_phred33 ? 'phred33' : ''));
my $file_format         = ($from_fasta ? 'fasta' :
			   ($from_fastq ? 'fastq' :
			    ($from_qseq ? 'qseq' : '')));
my $qual_format         = ($from_phred64 ? 'phred64' :
			   ($from_phred33 ? 'phred33' : ''));
my $input_qual_file     = '';
my $mixed_format_warned = 0;
my $mixed_qual_warned   = 0;

#For each input file
foreach my $input_file (@seq_files)
  {
    ##
    ## Check the input file formats
    ##

    #If we're sure this is fasta format (by the existence of separate quality
    #files), check the format of the two files are both fasta
    if(scalar(@qual_files))
      {
	#Get the corresponding quality file (assuming same order)
	$input_qual_file = shift(@qual_files);

	#Check the file format
	($file_format,$qual_format) = getFileFormat($input_file,
						    $input_qual_file,
						    $skip_format_check);

	verbose("[$input_file] is format: [$file_format] quality format: ",
		"[$qual_format]");

	#Check format consistency among multiple files (assumes global already
	#set above)
	if($global_file_format ne $file_format)
	  {
	    error("Expected fasta format, but your input file: [$input_file] ",
		  "appears to be in ",
		  ($file_format eq '' ? 'an unknown' : "[$file_format]"),
		  " format.  Skipping $input_file and $input_qual_file.");
	    next;
	  }

	#If the quality format could not be determined, skip these files
	if($qual_format eq '')
	  {
	    error("Unable to parse [$input_qual_file].  Skipping.");
	    next;
	  }

	#Set the global quality format if not already set
	if($global_qual_format eq '')
	  {$global_qual_format = $qual_format}
	#If the global quality format differs from the format of current file
	elsif($global_qual_format ne $qual_format && !$mixed_qual_warned)
	  {
	    #If the global format is phred64, it's possible that a
	    #determination of the other (phred33) could reasonably be phred64,
	    #just without any negative qualities, so quietly change it to
	    #phred64
	    if($from_phred64 || $global_qual_format eq 'phred64')
	      {$qual_format = 'phred64'}
	    elsif(defined($from_phred33) && defined($from_phred64) &&
		  (($from_phred33 && $qual_format eq 'phred64') ||
		   ($from_phred64 && $qual_format eq 'phred33')))
	      {
		#Warn the user that the file was not in the expected format
		warning(($from_phred33 ? 'phred33' : 'phred64')," was ",
			"expected, but the quality file: [$input_qual_file] ",
			"appears to be in [$qual_format] format.");
	      }
	    else
	      {
		#Warn the user about the mix of quality formats and suggest
		#they set the format on the command line & re-run
		warning("Your input files appear to consist of a mix of at ",
			"least $global_qual_format and $qual_format.  ",
			((!$to_phred64 && !$to_phred33) ?
			 join('',("Plus, you have not specified a quality ",
				  "format (e.g. --solexa-qual or --sanger-",
				  "qual), so your output will consist of ",
				  "mixed quality formats as well.  Specify ",
				  "--from-solexa-qual to force all files ",
				  "to be considered as phred64-based.  ")) :
			 ''),
			"This is only a problem if this is unexpected.");
		$mixed_qual_warned = 1;
	      }
	  }
      }
    else #Check the specified formats
      {
	debug("There were [",scalar(@qual_files),"] quality files.");

	#Determine the format to check against what formats were found earlier
	#or if a format was specified on the command line, check against that.
	($file_format,$qual_format) = getFileFormat($input_file,
						    undef,
						    $skip_format_check);

	verbose("[$input_file] is format: [$file_format] quality format: ",
		"[$qual_format]");

	#If either format was not able to be determined, skip it.
	if($file_format eq '' || $qual_format eq '')
	  {
	    error("Unable to parse the ",
		  ($qual_format eq '' ? 'quality' : 'sequence'),
		  " format from sequence file: [",
		  ($input_file eq '-' ? 'STDIN' : $input_file),
		  "].  Skipping.");
	    next;
	  }

	#Set the global value if not already set
	if($global_file_format eq '')
	  {$global_file_format = $file_format}
	#If the global value differs and no warning has yet been issued
	elsif($global_file_format ne $file_format && !$mixed_format_warned)
	  {
	    #If the format was forced on the command line, error out and skip
	    if($from_fasta || $from_fastq || $from_qseq)
	      {
		error("Your sequence file: [$input_file] was expected to be ",
		      "in [$global_file_format] format, but appears to be in ",
		      "[$file_format].  Skipping.");
		next;
	      }
	    else #Warn the user of mixed input formats detected
	      {
		warning("Your input files appear to consist of a mix of at ",
			"least $global_file_format and $file_format.  This ",
			"is only a problem if this is unexpected.");
		$mixed_format_warned = 1;
	      }
	  }

	#Set the global quality format if not already set
	if($global_qual_format eq '')
	  {$global_qual_format = $qual_format}
	#If the global value differs and no warning has yet been issued
	elsif($global_qual_format ne $qual_format && !$mixed_qual_warned)
	  {
	    #If phred64 has been explicitly set, quietly correct the guess
	    if($from_phred64)
	      {$qual_format = 'phred64'}
	    #Else if the format was forced on the command line, error out and
	    #skip
	    elsif($from_phred33)
	      {
		error("Your sequence file: [$input_file] was expected to ",
		      "have qualities scores in [$global_qual_format] ",
		      "format, but appears to be in [$qual_format].  ",
		      "Skipping.");
		next;
	      }
	    else #Warn the user of mixed input formats detected
	      {
		warning("Your input files appear to consist of a mix of at ",
			"least $global_qual_format and $qual_format.  This ",
			"is only a problem if this is unexpected.");
		$mixed_qual_warned = 1;
	      }
	  }
      }


    ##
    ## Open the output file(s)
    ##


    #If an output file name suffix has been defined
    if(defined($fasta_seq_suffix))
      {
	#Set the current output file name
	$current_output_fasta_seq_file = ($input_file eq '-' ? 'STDIN' :
					  $input_file) . $fasta_seq_suffix;

	#Open the output file
	if(!open(FASTASEQ,">$current_output_fasta_seq_file"))
	  {
	    #Report an error and iterate if there was an error
	    error("Unable to open output file: ",
		  "[$current_output_fasta_seq_file].\n$!");
	    next;
	  }
	else
	  {verbose("[$current_output_fasta_seq_file] Opened output file.")}

	#Store info. about the run as a comment at the top of the output file
	print FASTASEQ ('#',join("\n#",split(/\n/,getVersion())),"\n",
			'#',scalar(localtime($^T)),"\n",
			'#',getCommand(1),"\n") unless($noheader);
      }

    #If an output file name suffix has been defined
    if(defined($fasta_qual_suffix))
      {
	#Set the current output file name
	$current_output_fasta_qual_file = ($input_file eq '-' ? 'STDIN' :
					   $input_file) . $fasta_qual_suffix;

	#Open the output file
	if(!open(FASTAQUAL,">$current_output_fasta_qual_file"))
	  {
	    #Report an error and iterate if there was an error
	    error("Unable to open output file: ",
		  "[$current_output_fasta_qual_file].\n$!");
	    next;
	  }
	else
	  {verbose("[$current_output_fasta_qual_file] Opened output file.")}

	#Store info. about the run as a comment at the top of the output file
	print FASTAQUAL ('#',join("\n#",split(/\n/,getVersion())),"\n",
			 '#',scalar(localtime($^T)),"\n",
			 '#',getCommand(1),"\n") unless($noheader);
      }

    #If an output file name suffix has been defined
    if(defined($fastq_suffix))
      {
	#Set the current output file name
	$current_output_fastq_file = ($input_file eq '-' ? 'STDIN' :
				      $input_file) . $fastq_suffix;

	#Open the output file
	if(!open(FASTQ,">$current_output_fastq_file"))
	  {
	    #Report an error and iterate if there was an error
	    error("Unable to open output file: ",
		  "[$current_output_fastq_file].\n$!");
	    next;
	  }
	else
	  {verbose("[$current_output_fastq_file] Opened output file.")}

	#Store info. about the run as a comment at the top of the output file
	print FASTQ ('#',join("\n#",split(/\n/,getVersion())),"\n",
		     '#',scalar(localtime($^T)),"\n",
		     '#',getCommand(1),"\n") unless($noheader);
      }

    #If an output file name suffix has been defined
    if(defined($qseq_suffix))
      {
	#Set the current output file name
	$current_output_qseq_file = ($input_file eq '-' ? 'STDIN' :
				     $input_file) . $qseq_suffix;

	#Open the output file
	if(!open(QSEQ,">$current_output_qseq_file"))
	  {
	    #Report an error and iterate if there was an error
	    error("Unable to open output file: ",
		  "[$current_output_qseq_file].\n$!");
	    next;
	  }
	else
	  {verbose("[$current_output_qseq_file] Opened output file.")}

	#Store info. about the run as a comment at the top of the output file
	print QSEQ ('#',join("\n#",split(/\n/,getVersion())),"\n",
		    '#',scalar(localtime($^T)),"\n",
		    '#',getCommand(1),"\n") unless($noheader);
      }


    ##
    ## Open the input file(s)
    ##


    #Open the input file
    if(!open(INPUT,$input_file))
      {
	#Report an error and iterate if there was an error
	error("Unable to open input file: [$input_file].\n$!");
	next;
      }
    else
      {verbose('[',($input_file eq '-' ? 'STDIN' : $input_file),'] ',
	       'Opened input sequence file.')}

    #If a fasta quality file was provided
    if(defined($input_qual_file) && $input_qual_file ne '')
      {
	#Open the input quality file
	if(!open(INPUTQUAL,$input_qual_file))
	  {
	    #Report an error and iterate if there was an error
	    error("Unable to open input file: [$input_qual_file].\n$!");
	    close(INPUT);
	    next;
	  }
	else
	  {verbose('[',($input_qual_file eq '-' ? 'STDIN' :
			$input_qual_file),'] ',
		   'Opened input quality file.')}
      }


    ##
    ## Process the input file and print output files
    ##


    my $rec_cnt = 0;

    if($from_fastq || $file_format eq 'fastq')
      {
	my $defline          = '';
	my $new_defline      = '';
	my $seq              = '';
	my $qual             = '';
	my $getting_sequence = 0;
	my $comment_buffer   = '';
	while(getLine(*INPUT))
	  {
	    chomp;
	    if(length($qual) >= length($seq) && /^\s*\@([^\n\r]*)/)
	      {
		$new_defline = $1;

		if($defline ne '' || $seq ne '' || $qual ne '')
		  {
		    verboseOverMe("Printing record ",++$rec_cnt," of file [",
				  ($input_file eq '-' ? 'STDIN' : $input_file),
				  "].");

		    if($to_qseq)
		      {
			#Select different output for the qualities
			defined($qseq_suffix) ? select(QSEQ) : select(STDOUT);

			#Print the previously captured sequence info
			print(fastqToQseq($defline,
					  $seq,
					  $qual,
					  $qual_format,
					  ($to_phred64 ? 'phred64' :
					   ($to_phred33 ? 'phred33' :
					    #Defaults to phred64 for qseq
					    'phred64'))),
			      ($comment_buffer ne '' ?
			       "$comment_buffer\n" : ''));
		      }

		    if($to_fasta)
		      {
			#Select different output for the qualities
			defined($fasta_seq_suffix) ?
			  select(FASTASEQ) : select(STDOUT);

			#Print the previously captured sequence info
			print(fastqToFastaSeq($defline,$seq),
			      ($comment_buffer ne '' ?
			       "$comment_buffer\n" : ''));

			#Do not output qualities if sequence suffix is
			#provided, but not a quality suffix provided
			if(defined($fasta_qual_suffix) ||
			   !defined($fasta_seq_suffix))
			  {
			    #Select different output for the qualities
			    defined($fasta_qual_suffix) ?
			      select(FASTAQUAL) : select(STDOUT);

			    #Reprint the defline data
			    print(fastqToFastaQual($defline,
						   $qual,
						   $seq,
						   $qual_format,
						   ($to_phred64 ? 'phred64' :
						    ($to_phred33 ? 'phred33' :
						     #Default to phred33 for fa
						     'phred33'))),
				  ($comment_buffer ne '' ?
				   "$comment_buffer\n" : ''));
			  }
		      }

		    if($to_fastq)
		      {
			#Select different output for the qualities
			defined($fastq_suffix) ?
			  select(FASTQ) : select(STDOUT);

			#Convert the quality scores if requested & necessary
			if($to_phred64 && $qual_format eq 'phred33')
			  {$qual = compressedPhred33toPhred64($qual)}
			elsif($to_phred33 && $qual_format eq 'phred64')
			  {$qual = compressedPhred64toPhred33($qual)}
			#Defaults to phred33 for fastq
			elsif(!$to_phred64 && !$to_phred33 &&
			      $qual_format eq 'phred64')
			  {$qual = compressedPhred64toPhred33($qual)}

			#Print the previously captured sequence info
			print("\@$defline\n$seq\n+",($no_qual_defline ? '' :
						     $defline),"\n$qual\n",
			      ($comment_buffer ne '' ?
			       "$comment_buffer\n" : ''));
		      }
		  }
		else
		  {
		    verboseOverMe("Printing comment from file [",
				  ($input_file eq '-' ? 'STDIN' : $input_file),
				  "].");

		    if($to_qseq)
		      {
			defined($qseq_suffix) ? select(QSEQ) : select(STDOUT);
			print($comment_buffer,"\n") if($comment_buffer ne '');
		      }
		    if($to_fasta)
		      {
			defined($fasta_seq_suffix) ?
			  select(FASTASEQ) : select(STDOUT);
			print($comment_buffer,"\n") if($comment_buffer ne '');
			defined($fasta_qual_suffix) ?
			  select(FASTAQUAL) : select(STDOUT);
			print($comment_buffer,"\n") if($comment_buffer ne '');
		      }
		    if($to_fastq)
		      {
			defined($fastq_suffix) ?
			  select(FASTQ) : select(STDOUT);
			print($comment_buffer,"\n") if($comment_buffer ne '');
		      }
		  }

		$comment_buffer   = '';
		$defline          = $new_defline;
		$qual             = '';
		$seq              = '';
		$getting_sequence = 1;
	      }
	    elsif($getting_sequence && /^\s*\+([^\n\r]*)/)
	      {$getting_sequence = 0}
	    elsif($getting_sequence)
	      {
		s/\s+//g;
		if(/^([A-Za-z\n\.~]*)$/)
		  {$seq .= $_}
		else
		  {
		    error("Expected a sequence character string, but ",
			  "got: [$_].  Appending anyway.");
		    $seq .= $_;
		  }
	      }
	    elsif($seq =~ /./)
	      {
		s/\s+//g;
		if(/^([\!-\~]*)$/)
		  {$qual .= $_}
		else
		  {
		    error("Expected a quality character string, but ",
			  "got: [$_].  Appending anyway.");
		    $qual .= $_;
		  }
	      }
	    else #Must be a comment, buffer it
	      {$comment_buffer .= $_}
	  }

	verboseOverMe("Printing record ",++$rec_cnt," of file [",
		      ($input_file eq '-' ? 'STDIN' : $input_file),"].");

	#Print last record
	if($to_qseq)
	  {
	    defined($qseq_suffix) ? select(QSEQ) : select(STDOUT);

	    #Print the previously captured sequence info
	    print(fastqToQseq($defline,
			      $seq,
			      $qual,
			      $qual_format,
			      ($to_phred64 ? 'phred64' :
			       ($to_phred33 ? 'phred33' :
				#Defaults to phred64 for qseq
				'phred64'))),
		  ($comment_buffer ne '' ? "$comment_buffer\n" : ''))
	      if($defline ne '' || $seq ne '' || $qual ne '');
	  }

	if($to_fasta)
	  {
	    #Select different output for the qualities
	    defined($fasta_seq_suffix) ? select(FASTASEQ) : select(STDOUT);

	    #Print the previously captured sequence info
	    print(fastqToFastaSeq($defline,$seq),"\n");

	    #Do not output qualities if sequence suffix is
	    #provided, but not a quality suffix provided
	    if(defined($fasta_qual_suffix) ||
	       !defined($fasta_seq_suffix))
	      {
		#Select different output for the qualities
		defined($fasta_qual_suffix) ?
		  select(FASTAQUAL) : select(STDOUT);

		#Reprint the defline data
		print(fastqToFastaQual($defline,
				       $qual,
				       $seq,
				       $qual_format,
				       ($to_phred64 ? 'phred64' :
					($to_phred33 ? 'phred33' :
					 #Defaults to phred33 for fasta
					 'phred33'))),
		      ($comment_buffer ne '' ? "$comment_buffer\n" : ''));
	      }
	  }

	if($to_fastq)
	  {
	    #Select different output for the qualities
	    defined($fastq_suffix) ? select(FASTQ) : select(STDOUT);

	    #Convert the quality scores if requested & necessary
	    if($to_phred64 && $qual_format eq 'phred33')
	      {$qual = compressedPhred33toPhred64($qual)}
	    elsif($to_phred33 && $qual_format eq 'phred64')
	      {$qual = compressedPhred64toPhred33($qual)}
	    #Defaults to phred33 for fastq
	    elsif(!$to_phred64 && !$to_phred33 &&
		  $qual_format eq 'phred64')
	      {$qual = compressedPhred64toPhred33($qual)}

	    #Print the previously captured sequence info
	    print("\@$defline\n$seq\n+",($no_qual_defline ? '' : $defline),
		  "\n$qual\n",($comment_buffer ne '' ? "$comment_buffer\n" :
			       ''));
	  }

	$comment_buffer = '';
      }
    elsif($from_qseq)
      {
	while(getLine(*INPUT))
	  {
	    chomp;
	    my @cols = split(/\t/,$_);

	    #Verbose message for this record
	    if(scalar(@cols) < 10)
	      {verboseOverMe("Printing comment from file [",
			     ($input_file eq '-' ? 'STDIN' : $input_file),
			     "].")}
	    else
	      {verboseOverMe("Printing record ",++$rec_cnt," of file [",
			     ($input_file eq '-' ? 'STDIN' : $input_file),
			     "].")}

	    if($to_qseq)
	      {
		defined($qseq_suffix) ? select(QSEQ) : select(STDOUT);

		#If not all columns are there, assume it's a comment line and
		#print it back out
		if(scalar(@cols) < 10)
		  {print}
		else
		  {
		    #Convert the quality scores if requested & necessary
		    if($to_phred64 && $qual_format eq 'phred33')
		      {$cols[9] = compressedPhred33toPhred64($cols[9])}
		    elsif($to_phred33 && $qual_format eq 'phred64')
		      {$cols[9] = compressedPhred64toPhred33($cols[9])}
		    #Defaults to phred64 for qseq
		    elsif(!$to_phred33 && !$to_phred64 &&
			  $qual_format eq 'phred33')
		      {$cols[9] = compressedPhred33toPhred64($cols[9])}

		    #Print the columns back out
		    print(join("\t",@cols),"\n");
		  }
	      }

	    if($to_fastq)
	      {
		defined($fastq_suffix) ? select(FASTQ) : select(STDOUT);

		#If not all columns are there, assume it's a comment line and
		#print it back out
		if(scalar(@cols) < 11)
		  {print}
		else
		  {
		    #Change dots to N's in the sequence, matching case
		    if($cols[8] =~ /^[a-z\.]+$/)
		      {$cols[8] =~ tr/\./n/}
		    else
		      {$cols[8] =~ tr/\./N/}

		    #Convert the quality scores if requested & necessary
		    if($to_phred64 && $qual_format eq 'phred33')
		      {$cols[9] = compressedPhred33toPhred64($cols[9])}
		    elsif($to_phred33 && $qual_format eq 'phred64')
		      {$cols[9] = compressedPhred64toPhred33($cols[9])}
		    #Defaults to phred33 for fastq
		    elsif(!$to_phred33 && !$to_phred64 &&
			  $qual_format eq 'phred64')
		      {$cols[9] = compressedPhred64toPhred33($cols[9])}

		    #Print the defline data the conventional way
		    print('@',join(':',@cols[0..5]),
			  "#$cols[6]/$cols[7]:$cols[10]\n",
			  "$cols[8]\n",
			  #Reprint the defline data (though not necessary)
			  '+',($no_qual_defline ? '' :
			       join(':',@cols[0..5]) .
			       "#$cols[6]/$cols[7]:$cols[10]"),
			  "\n$cols[9]",
			  #Add the terminator unless it's already there
			  ((length($cols[8]) + 1) == length($cols[9]) ? '' :
			   $quality_terminator),
			  "\n");
		  }
	      }

	    if($to_fasta)
	      {
		defined($fasta_seq_suffix) ? select(FASTASEQ) : select(STDOUT);

		#If not all columns are there, assume it's a comment line and
		#print it back out
		if(scalar(@cols) < 10)
		  {print}
		else
		  {
		    #Change dots to N's in the sequence, matching case
		    if($cols[8] =~ /^[a-z\.]+$/)
		      {$cols[8] =~ tr/\./n/}
		    else
		      {$cols[8] =~ tr/\./N/}

		    #Print the defline data the conventional way
		    print('>',join(':',@cols[0..5]),
			  "#$cols[6]/$cols[7]:$cols[10]\n",
			  "$cols[8]\n");

		    #Do not output qualities if sequence suffix is
		    #provided, but not a quality suffix provided
		    if(defined($fasta_qual_suffix) ||
		       !defined($fasta_seq_suffix))
		      {
			#Select different output for the qualities
			defined($fasta_qual_suffix) ?
			  select(FASTAQUAL) : select(STDOUT);

			#Convert the quality scores if requested & necessary
			if($to_phred64 && $qual_format eq 'phred33')
			  {$cols[9] = compressedPhred33toPhred64($cols[9])}
			elsif($to_phred33 && $qual_format eq 'phred64')
			  {$cols[9] = compressedPhred64toPhred33($cols[9])}
			#Defaults to phred33 for fasta
			elsif(!$to_phred33 && !$to_phred64 &&
			      $qual_format eq 'phred64')
			  {$cols[9] = compressedPhred64toPhred33($cols[9])}

			if($to_phred64 || (!$to_phred64 && !$to_phred33 &&
					   $qual_format eq 'phred64'))
			  {$cols[9] = decompressPhred64Qualities($cols[9])}
			elsif($to_phred33 || (!$to_phred64 && !$to_phred33 &&
					      $qual_format eq 'phred33'))
			  {$cols[9] = decompressPhred33Qualities($cols[9])}

			#Reprint the defline data
			print('>',join(':',@cols[0..5]),
			      "#$cols[6]/$cols[7]:$cols[10]\n",
			      "$cols[9]\n");
		      }
		  }
	      }
          }
      }
    elsif($from_fasta)
      {
	my $qual_hash = {};
	my $seq_rec   = [];
	my $qual_rec  = [];
	my $seq_id    = '';
	my $f_rec_num = 0;
	my $q_rec_num = 0;
	my($defline,$seq,$qual,$qual_defline,$comments,$qual_comments);
	while($seq_rec = getNextFastaRec(*INPUT))
	  {
	    ($defline,$seq,$comments) = @$seq_rec;

	    $f_rec_num++;

	    #Get the sequence ID
	    if($defline =~ /^\s*>\s*(\S+)/)
	      {$seq_id = $1}

	    #Loop until we find the corresponding quality record
	    while(!exists($qual_hash->{$seq_id}) &&
		  ($qual_rec = getNextFastaRec(*INPUTQUAL,1)))
	      {
		($qual_defline,$qual,$qual_comments) = @$qual_rec;

		$q_rec_num++;

		verboseOverMe("Reading record ",$q_rec_num," of file ",
			      "[$input_qual_file].");

		#Grab the quality ID & update the hash (to buffer in case
		#the files aren't in the same order)
		if($qual_defline =~ /^\s*>\s*(\S+)/)
		  {$qual_hash->{$1} = $qual}
		else
		  {error("Unable to parse defline: [$qual_defline] in ",
			 "quality file: [$input_qual_file]: [$qual_defline].")}
	      }

	    #If we found the ID in the quality file
	    if(exists($qual_hash->{$seq_id}))
	      {
		#Verbose message for this record
		if($comments)
		  {verboseOverMe("Printing comment from file [",
				 ($input_file eq '-' ? 'STDIN' : $input_file),
				 "].")}

		verboseOverMe("Printing record ",++$rec_cnt," of file [",
			      ($input_file eq '-' ? 'STDIN' : $input_file),
			      "].");

		if($to_qseq)
		  {
		    defined($qseq_suffix) ? select(QSEQ) : select(STDOUT);

		    print(($comments ? "$comments\n" : ''),
			  fastaToQseq($defline,
				      $seq,
				      $qual_hash->{$seq_id},
				      $qual_format,
				      ($to_phred64 ? 'phred64' :
				       ($to_phred33 ? 'phred33' :
					#Defaults to phred64 for qseq
					'phred64'))));
		  }

		if($to_fasta)
		  {
		    defined($fasta_seq_suffix) ?
		      select(FASTASEQ) : select(STDOUT);

		    print(($comments ? "$comments\n" : ''),"$defline\n$seq\n");

		    #Do not output qualities if sequence suffix is
		    #provided, but not a quality suffix provided
		    if(defined($fasta_qual_suffix) ||
		       !defined($fasta_seq_suffix))
		      {
			defined($fasta_qual_suffix) ?
			  select(FASTAQUAL) : select(STDOUT);

			#Convert the quality scores if requested & necessary
			if($to_phred64 && $qual_format eq 'phred33')
			  {$qual_hash->{$seq_id} =
			     uncompressedPhred33toPhred64($qual_hash
							  ->{$seq_id})}
			elsif($to_phred33 && $qual_format eq 'phred64')
			  {$qual_hash->{$seq_id} =
			     uncompressedPhred64toPhred33($qual_hash
							  ->{$seq_id})}
			elsif(!$to_phred33 && !$to_phred33 &&
			      $qual_format eq 'phred64')
			  {$qual_hash->{$seq_id} =
			     uncompressedPhred64toPhred33($qual_hash
							  ->{$seq_id})}

			print(($qual_comments ? "$qual_comments\n" : ''),
			      "$defline\n$qual_hash->{$seq_id}\n");
		      }
		  }

		if($to_fastq)
		  {
		    defined($fastq_suffix) ? select(FASTQ) : select(STDOUT);

		    print(($comments ? "$comments\n" : ''),
			  ($qual_comments ? "$qual_comments\n" : ''),
			  fastaToFastq($defline,
				       $seq,
				       $qual_hash->{$seq_id},
				       $qual_format,
				       ($to_phred64 ? 'phred64' :
					($to_phred33 ? 'phred33' :
					 #Defaults to phred33 for fastq
					 'phred33')),
				       $quality_terminator));
		  }

		#Remove the record from the buffer so we can check for
		#leftovers when we're done
		delete($qual_hash->{$seq_id});
	      }
	    else
	      {error("Sequence [$seq_id] in sequence file [$input_file] ",
		     "was not found in the corresponding quality file: ",
		     "[$input_qual_file].")}
	  }

	#See if any IDs from the quality file were left over
	if(!$ignore_extra_quals && scalar(keys(%$qual_hash)))
	  {error("The following quality record IDs from quality file ",
		 "[$input_qual_file] were not found in the ",
		 "corresponding sequence file [$input_file]: [",
		 join(',',keys(%$qual_hash)),"].")}
      }


    close(INPUT);

    #If a fasta quality file was provided
    if(defined($input_qual_file) && $input_qual_file ne '')
      {verbose("[$input_qual_file] Closed input file.  Time taken: [",
	       scalar(markTime()),' Seconds].')}

    verbose('[',($input_file eq '-' ? 'STDIN' : $input_file),'] ',
	    'Closed input file.  Time taken: [',scalar(markTime()),
	    ' Seconds].');

    #If an output file name suffix is set
    if(defined($fasta_seq_suffix))
      {
	#Close the output file handle
	close(FASTASEQ);
	verbose("[$current_output_fasta_seq_file] Closed output file.");
      }
    #If an output file name suffix is set
    if(defined($fasta_qual_suffix))
      {
	#Close the output file handle
	close(FASTAQUAL);
	verbose("[$current_output_fasta_qual_file] Closed output file.");
      }
    #If an output file name suffix is set
    if(defined($fastq_suffix))
      {
	#Close the output file handle
	close(FASTQ);
	verbose("[$current_output_fastq_file] Closed output file.");
      }
    #If an output file name suffix is set
    if(defined($qseq_suffix))
      {
	#Close the output file handle
	close(QSEQ);
	verbose("[$current_output_qseq_file] Closed output file.");
      }
    select(STDOUT);
  }



verbose("[STDOUT] Closed standard output.")
  if(((!defined($fasta_seq_suffix) || !defined($fasta_qual_suffix)) &&
      $to_fasta) ||
     (!defined($fastq_suffix) && $to_fastq) ||
     (!defined($qseq_suffix) && $to_qseq));

#Report the number of errors, warnings, and debugs on STDERR
if(!$quiet && ($verbose                     ||
	       $DEBUG                       ||
	       defined($main::error_number) ||
	       defined($main::warning_number)))
  {
    print STDERR ("\n",'Done.  EXIT STATUS: [',
		  'ERRORS: ',
		  ($main::error_number ? $main::error_number : 0),' ',
		  'WARNINGS: ',
		  ($main::warning_number ? $main::warning_number : 0),
		  ($DEBUG ?
		   ' DEBUGS: ' .
		   ($main::debug_number ? $main::debug_number : 0) : ''),' ',
		  'TIME: ',scalar(markTime(0)),"s]\n");

    if($main::error_number || $main::warning_number)
      {print STDERR ("Scroll up to inspect errors and warnings.\n")}
  }

##
## End Main
##






























##
## Subroutines
##

sub fastqToQseq
  {
    my $defline          = $_[0];
    my $seq              = $_[1];
    my $qual             = $_[2];
    my $from_qual_format = $_[3]; #Must be 'phred64' or 'phred33'
    my $to_qual_format   = $_[4]; #Values above or empty string (no conversion)
    #Format of the qual string is required to be compressed (check)
    my $new_str = '';

    #Error-check input
    if(scalar(@_) < 3)
      {
	error("Not all required values passed in.  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($defline) || $defline eq '')
      {
	error("Undefined defline passed in.  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($seq) || $seq eq '')
      {
	error("Undefined sequence passed in.  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($qual) || $qual eq '')
      {
	error("Undefined quality string passed in.  Returning empty string.");
	return($new_str);
      }

    if(defined($from_qual_format) && $from_qual_format ne '' &&
       defined($to_qual_format)   && $to_qual_format   ne '')
      {
	#Convert the quality scores if requested & necessary
	if($to_qual_format eq 'phred64' && $from_qual_format eq 'phred33')
	  {$qual = compressedPhred33toPhred64($qual)}
	elsif($to_qual_format eq 'phred33' && $from_qual_format eq 'phred64')
	  {$qual = compressedPhred64toPhred33($qual)}
      }

    #Change N's to dots in the sequence
    $seq =~ tr/nN/\.\./;

    #Assume there's a terminator (!) if the quality string is one character
    #longer than the sequence
    if(length($seq) + 1 == length($qual))
      {chop($qual)}

    if(length($seq) != length($qual))
      {
	error("The length of the sequence for [$defline] is not equal to the ",
	      "length of the quality string.  Printing anyway.");
      }

    $new_str = getQseqCols($defline,$seq,$qual);

    return($new_str);
  }

sub fastqToFastaSeq
  {
    my $defline = $_[0];
    my $seq     = $_[1];
    my $new_str = '';

    #Error-check input
    if(scalar(@_) < 2)
      {
	error("Not all required values passed in.  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($defline) || $defline eq '')
      {
	error("Undefined defline passed in.  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($seq) || $seq eq '')
      {
	error("Undefined sequence passed in.  Returning empty string.");
	return($new_str);
      }

    #Remove the defline character (if there is one)
    $defline =~ s/^\s*\@\s*//;
    chomp($defline);
    chomp($seq);

    $new_str = ">$defline\n$seq\n";

    return($new_str);
  }

sub fastqToFastaQual
  {
    my $defline          = $_[0];
    my $qual             = $_[1];
    my $seq              = $_[2];
    my $from_qual_format = $_[3];
    my $to_qual_format   = $_[4];
    my $new_str          = '';

    #Error-check input
    if(scalar(@_) < 5)
      {
	error("Not all required values passed in.  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($defline) || $defline eq '')
      {
	error("Undefined defline passed in.  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($seq) || $seq eq '')
      {
	error("Undefined sequence passed in.  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($qual) || $qual eq '')
      {
	error("Undefined quality string passed in.  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($from_qual_format) || $from_qual_format eq '')
      {
	error("Undefined from-quality format passed in.  Returning empty ",
	      "string.");
	return($new_str);
      }
    elsif(!defined($to_qual_format) || $to_qual_format eq '')
      {
	error("Undefined to-quality format passed in.  Returning empty ",
	      "string.");
	return($new_str);
      }

    #Convert the quality scores if requested & necessary
    if($to_qual_format eq 'phred64' && $from_qual_format eq 'phred33')
      {$qual = compressedPhred33toPhred64($qual)}
    elsif($to_qual_format eq 'phred33' && $from_qual_format eq 'phred64')
      {$qual = compressedPhred64toPhred33($qual)}
    elsif($from_qual_format ne 'phred33' && $from_qual_format ne 'phred64')
      {
	error("Unrecognized from-quality format: [$from_qual_format].  ",
	      "Returning empty string.");
	return($new_str);
      }
    elsif($to_qual_format ne 'phred33' && $to_qual_format ne 'phred64')
      {
	error("Unrecognized to-quality format: [$to_qual_format].  Returning ",
	      "empty string.");
	return($new_str);
      }

    #Eliminate terminator if present before decompressing
    if(defined($seq) && length($seq) + 1 == length($qual))
      {chop($qual)}

    #Decompress the quality string to space-separated numbers
    if($to_qual_format eq 'phred64')
      {$qual = decompressPhred64Qualities($qual)}
    elsif($to_qual_format eq 'phred33')
      {$qual = decompressPhred33Qualities($qual)}

    chomp($defline);
    chomp($qual);
    $defline =~ s/^\s*\+\s*//;
    $new_str = ">$defline\n$qual\n";

    return($new_str);
  }

sub fastaToQseq
  {
    my $defline          = $_[0];
    my $seq              = $_[1];
    my $qual             = $_[2];
    my $from_qual_format = $_[3]; #Must be 'phred64' or 'phred33'
    my $to_qual_format   = $_[4]; #Values above or empty string (no conversion)
    #Format of the qual string is required to be uncompressed (check)
    my $new_str          = '';

    #Error-check input
    if(scalar(@_) < 5)
      {
	error("Not all required values passed in.  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($defline) || $defline eq '')
      {
	error("Undefined defline passed in.  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($seq) || $seq eq '')
      {
	error("Undefined sequence passed in.  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($qual) || $qual eq '')
      {
	error("Undefined quality string passed in.  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($from_qual_format) || $from_qual_format eq '')
      {
	error("Undefined from-quality format passed in.  Returning empty ",
	      "string.");
	return($new_str);
      }
    elsif(!defined($to_qual_format) || $to_qual_format eq '')
      {
	error("Undefined to-quality format passed in.  Returning empty ",
	      "string.");
	return($new_str);
      }

    #Change N's to dots in the sequence
    $seq =~ tr/nN/\.\./;

    #Compress the quality scores
    if($from_qual_format eq 'phred64')
      {$qual = compressPhred64Qualities($qual)}
    elsif($from_qual_format eq 'phred33')
      {$qual = compressPhred33Qualities($qual)}
    else
      {
	error("Unrecognized quality format: [$from_qual_format].  Returning ",
	      "empty string.");
	return($new_str);
      }

    #Convert the quality scores if requested & necessary
    if($to_qual_format eq 'phred64' && $from_qual_format eq 'phred33')
      {$qual = compressedPhred33toPhred64($qual)}
    elsif($to_qual_format eq 'phred33' && $from_qual_format eq 'phred64')
      {$qual = compressedPhred64toPhred33($qual)}

    $new_str = getQseqCols($defline,$seq,$qual);

    return($new_str);
  }

#Uses global: $no_qual_defline
sub fastaToFastq
  {
    my $defline          = $_[0];
    my $seq              = $_[1];
    my $qual             = $_[2];
    my $from_qual_format = $_[3]; #Must be 'phred64' or 'phred33'
    my $to_qual_format   = $_[4]; #Values above or empty string (no conversion)
    #Format of the qual string is required to be uncompressed (check)
    my $new_str          = '';

    #Error-check input
    if(scalar(@_) < 5)
      {
	error("Not all required values passed in.  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($defline) || $defline eq '')
      {
	error("Undefined defline passed in.  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($seq) || $seq eq '')
      {
	error("Undefined sequence passed in.  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($qual) || $qual eq '')
      {
	error("Undefined quality string passed in.  Returning empty string.");
	return($new_str);
      }
    elsif($qual !~ /^[0-9\s\n]+$/)
      {
	my @errors = ($qual =~ /([^0-9\s\n]+)/g);
	my $errstr = join('',@errors);
	$errstr =~ s/^(.{20}).*/$1.../;
	error("Invalid quality string passed in containing these invalid ",
	      "characters: [$errstr].  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($from_qual_format) || $from_qual_format eq '')
      {
	error("Undefined from-quality format passed in.  Returning empty ",
	      "string.");
	return($new_str);
      }
    elsif(!defined($to_qual_format) || $to_qual_format eq '')
      {
	error("Undefined to-quality format passed in.  Returning empty ",
	      "string.");
	return($new_str);
      }

    chomp($defline);
    chomp($seq);
    chomp($qual);

    #Get rid of the defline character
    $defline =~ s/^\s*\>\s*//;
    #Replace illegal defline characters with :'s
#    $defline =~ s/[^A-Za-z0-9_.:\-#\/]/:/g;

    #Compress the quality scores
    if($from_qual_format eq 'phred64')
      {$qual = compressPhred64Qualities($qual)}
    elsif($from_qual_format eq 'phred33')
      {$qual = compressPhred33Qualities($qual)}
    else
      {
	error("Unrecognized quality format: [$from_qual_format].  Returning ",
	      "empty string.");
	return($new_str);
      }

    #Convert the quality scores if requested & necessary
    if($to_qual_format eq 'phred64' && $from_qual_format eq 'phred33')
      {$qual = compressedPhred33toPhred64($qual)}
    elsif($to_qual_format eq 'phred33' && $from_qual_format eq 'phred64')
      {$qual = compressedPhred64toPhred33($qual)}

    $new_str = "\@$defline\n$seq\n+" . ($no_qual_defline ? '' : $defline) .
      "\n$qual\n";

    return($new_str);
  }

sub getQseqCols
  {
    my $defline = $_[0];
    my $seq     = $_[1];
    my $qual    = $_[2];
    my $new_str = '';
    #Assumed sequence and quality strings have already been converted to proper
    #format

    #Error-check input
    if(scalar(@_) < 3)
      {
	error("Not all required values passed in.  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($defline) || $defline eq '')
      {
	error("Undefined defline passed in.  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($seq) || $seq eq '')
      {
	error("Undefined sequence passed in.  Returning empty string.");
	return($new_str);
      }
    elsif(!defined($qual) || $qual eq '')
      {
	error("Undefined quality string passed in.  Returning empty string.");
	return($new_str);
      }

    if($qual =~ /^[ \d\-\n]+$/s)
      {
	error("Quality string appears to be in uncompressed format.  You ",
	      "must compress your quality string before using this ",
	      "subroutine.  Returning empty string.");
	return($new_str);
      }

    chomp($defline);
    $defline =~ s/^\s*[@>]\s*//;
    chomp($seq);
    $seq =~ s/[\s\r\n]//sg;
    chomp($qual);
    $qual =~ s/[\s\r\n]//sg;

    #Column order:
    #MachineID,run#,lane#,tile#,x-coord,y-coord,index,read#,sequence,q-sores,
    #p/f flag (This last one isn't in the defline usually)

    #$parts[0]:$parts[2]:$parts[3]:$parts[4]:$parts[5]#$parts[6]/$parts[7]\n
    my($machine,$run,$lane,$title,$x,$y,$index,$read,$pf_flag);
    my @buffer = ();
    @buffer = split(/:|#|\//,$defline);

    if(scalar(@buffer) < 8)
      {
	warning("Unable to parse defline: [$defline] to convert to qseq ",
		"format.  File will be incorrect or incomplete.");
      }

    ($machine,$run,$lane,$title,$x,$y,$index,$read,$pf_flag) = @buffer;

    $machine = '' if(!defined($machine));
    $run     = '' if(!defined($run));
    $lane    = '' if(!defined($lane));
    $title   = '' if(!defined($title));
    $x       = '' if(!defined($x));
    $y       = '' if(!defined($y));
    $index   = '' if(!defined($index));
    $read    = '' if(!defined($read));
    $pf_flag = (!defined($pf_flag) ? (!defined($read) ? '' : 0) : $pf_flag);

    $new_str = "$machine\t$run\t$lane\t$title\t$x\t$y\t$index\t$read\t$seq" .
      "\t$qual\t$pf_flag\n";

    return($new_str);
  }

sub decompressPhred64Qualities
  {return(decompressPhred33Qualities($_[0],64))}

sub decompressPhred33Qualities
  {
    my $str     = $_[0]; #Multiple quality character string
    my $offset  = (defined($_[1]) ? $_[1] : 33); #Internal var: do not supply
    my $new_str = '';

    chomp($str);

    if($str =~ /^[0-9 ]+$/ && $str =~ / /)
      {
	warning("Your compressed quality string appears to not be in the ",
		"expected phred64 format: [$str].");
	return($str);
      }

    #Convert the character qualities to space-separated numeric qualities
    $new_str = join(' ',map {ord($_) - $offset} split(//,$str));

    return($new_str);
  }

sub compressPhred64Qualities
  {return(compressPhred33Qualities($_[0],64))}

sub compressPhred33Qualities
  {
    my $str     = $_[0]; #Multiple quality character string
    my $offset  = (defined($_[1]) ? $_[1] : 33); #Internal var: do not supply
    my $new_str = '';
    chomp($str);

    if($str =~ /^\d{1,2}.+$/ && $str !~ / /)
      {
	warning("Your uncompressed quality string appears to not be in the ",
		"expected format: [$str].");
	return($str);
      }

    foreach my $c (grep {/\d/} split(/[ \n]+/,$str))
      {$new_str .= ($c !~ /\D/ ? chr(($c <= (126 - $offset) ?
				      $c : (126 - $offset)) + $offset) : 'ER')}

    return($new_str);
  }

#Convert ASCII characters phred33 to phred64
sub uncompressedPhred33toPhred64
  {
    my $str     = $_[0]; #Multiple quality character string
    my $new_str = '';
    chomp($str);

    if($str =~ /^\d{1,2}.+$/ && $str !~ / /)
      {
	warning("Your uncompressed quality string appears to not be in the ",
		"expected format: [$str].");
	return($str);
      }

    foreach my $c (grep {/\d/} split(/[ \n]+/,$str))
      {
	my $n     = 10 * log(exp(log(10) * ($c / 10)) - 1) / log(10);
	my $nn    = int(($n - int($n)) < .5 ? $n : ($n+1));
	$new_str .= $nn . ' ';
      }

    chop($new_str);
    return($new_str);
  }

#Convert ASCII characters phred64 to phred33
sub uncompressedPhred64toPhred33
  {
    my $str     = $_[0]; #Multiple quality character string
    my $new_str = '';

    if($str =~ /^\d{1,2}.+$/ && $str !~ / /)
      {
	warning("Your uncompressed quality string appears to not be in the ",
		"expected format: [$str].");
	return($str);
      }

    foreach my $c (grep {/\d/} split(/[ \n]+/,$str))
      {
	my $n     = 10 * log(1 + 10 ** ($c / 10.0)) / log(10);
	my $nn    = int(($n - int($n)) < .5 ? $n : ($n+1));
	$new_str .= $nn . ' ';
      }

    chop($new_str);
    return($new_str);
  }

#Convert ASCII characters phred33 to phred64
sub compressedPhred33toPhred64
  {
    my $str     = $_[0]; #Multiple quality character string
    my $new_str = '';

    if($str =~ /^[0-9 ]+$/ && $str =~ / /)
      {
	warning("Your compressed quality string appears to not be in the ",
		"expected phred64 format: [$str].");
	return($str);
      }

    foreach my $c (split(//,$str))
      {
	my $n     = 10 * log(exp(log(10) * ((ord($c) - 33) / 10)) - 1) /
	  log(10);
	my $nn    = int(($n - int($n)) < .5 ? $n : ($n+1)) + 64;
	$new_str .= chr($nn);
      }

    return($new_str);
  }

#Convert ASCII characters phred64 to phred33
sub compressedPhred64toPhred33
  {
    my $str     = $_[0]; #Multiple quality character string
    my $new_str = '';

    if($str =~ /^[0-9 ]+$/ && $str =~ / /)
      {
	warning("Your compressed quality string appears to not be in the ",
		"expected phred64 format: [$str].");
	return($str);
      }

    foreach my $c (split(//,$str))
      {
	my $n     = 10 * log(1 + 10 ** ((ord($c) - 64) / 10.0)) / log(10);
	my $nn    = int(($n - int($n)) < .5 ? $n : ($n+1)) + 33;
	$new_str .= chr($nn);
      }

    return($new_str);
  }

#Copied from fetch_cog.pl.pl on 8/6/2008 -Rob
sub getNextFastaRec
  {
#    my $self       = shift(@_);
    my $handle    = $_[0];      #File handle or file name
    my $no_format = $_[1];

    if(exists($main::{FASTABUFFER}) && exists($main::{FASTABUFFER}->{$handle}))
      {
	if(scalar(@{$main::{FASTABUFFER}->{$handle}}) > 0)
	  {
	    if(wantarray)
	      {
		my @array = (@{$main::{FASTABUFFER}->{$handle}});
		@{$main::{FASTABUFFER}->{$handle}} = ();
		return(@array);
	      }
	    return(shift(@{$main::{FASTABUFFER}->{$handle}}));
	  }
	elsif(eof($handle))
	  {return(undef)}
      }

    my $parent_id_check = {};
    my $first_loop      = 0;
    my $line_num        = 0;
    my $line            = '';
    my $defline         = '';
    my $comments        = '';
    my $next_comments   = '';
    my($seq);

    #For each line in the current input file
    while(getLine($handle))
      {
	$line_num = $.;
	$line = $_;

	if($line !~ /\S/ || $line =~ /^\s*#/)
	  {
	    $comments      .= $line unless(defined($seq));
	    $next_comments .= $line if(defined($seq));
	    next;
	  }

	if($line =~ />/)
	  {
	    if($defline)
	      {
		my $solidseq =
		  ($no_format ? $seq :
		   formatSequence($seq));
		chomp($solidseq);
		chomp($defline);
		chomp($comments);

		push(@{$main::{FASTABUFFER}->{$handle}},
		     [$defline,$solidseq,$comments]);
		$comments = $next_comments;
		$next_comments = '';
	      }
	    $defline  = $line;

	    my $tmp_id = $defline;
	    $tmp_id =~ s/^\s*>\s*//;
	    $tmp_id =~ s/\s.*//;
	    if($tmp_id eq '')
	      {warning("No Defline ID on line: [$line_num] of current file.  ",
		       " Universal coordinates will be used if some were ",
		       "supplied either via command line arguments of via ",
		       "coordinate file with no parent sequence ID.")}
	    elsif(exists($parent_id_check->{$tmp_id}))
	      {error("Two sequences found with the same ID on the ",
		     "defline: [$tmp_id] in current fasta file.  The same ",
		     "pairs of coordinates will be used for each sequence.")}

	    undef($seq);
	  }
	elsif($line =~ /^([^\t]+?) *\t\s*(.*)/)
	  {
	    $defline = $1;
	    $seq     = $2;

	    my $solidseq =
	      ($no_format ? $seq :
	       formatSequence($seq));
	    chomp($solidseq);
	    chomp($defline);
	    chomp($comments);

	    push(@{$main::{FASTABUFFER}->{$handle}},
		 [$defline,$solidseq,$comments]);

	    undef($seq);
	    $comments = $next_comments;
	    $next_comments = '';
	  }
	else
	  {$seq .= $line}
      }

    #Handle the last sequence (if there were any sequences)
    if(defined($seq))
      {
	my $solidseq =
	  ($no_format ? $seq :
	   formatSequence($seq));
	chomp($solidseq);
	chomp($defline);
	$comments .= $next_comments;
	chomp($comments);

	push(@{$main::{FASTABUFFER}->{$handle}},
	     [$defline,$solidseq,$comments]);
      }

    #Return the first sequence (if sequence was parsed)
    if(exists($main::{FASTABUFFER}) && exists($main::{FASTABUFFER}->{$handle}))
      {
	if(scalar(@{$main::{FASTABUFFER}->{$handle}}) > 0)
	  {
	    if(wantarray)
	      {
		my @array = (@{$main::{FASTABUFFER}->{$handle}});
		@{$main::{FASTABUFFER}->{$handle}} = ();
		return(@array);
	      }
	    return(shift(@{$main::{FASTABUFFER}->{$handle}}));
	  }
	else
	  {return(undef)}
      }
    else
      {return(undef)}
  }

#Dynamically determine the sequence file format (fasta, fastq, or qseq)
#Uses these global variables: $from_phred33,$from_phred64,$from_qseq,
#$from_fasta,$from_fastq
sub getFileFormat
  {
    my $input_file        = $_[0];
    my $input_qual_file   = $_[1]; #OPTIONAL
    my $skip_format_check = defined($_[2]) ? $_[2] : 0; #OPTIONAL

    #These variables will store the determined formats
    my $file_format = '';
    my $qual_format = '';

    if($skip_format_check)
      {
	if(!defined($from_phred33) || !defined($from_phred64) ||
	   ($from_phred33 + $from_phred64 == 0))
	  {error("No input quality format was specified.")}
	else
	  {$qual_format = ($from_phred33 ? 'phred33' : 'phred64')}

	if(!defined($from_fasta) || !defined($from_fastq) ||
	   !defined($from_qseq) ||
	   ($from_fasta + $from_fastq + $from_qseq == 0))
	  {error("No input file format was specified.")}
	else
	  {$file_format = ($from_fasta ? 'fasta' :
			   ($from_fastq ? 'fastq' : 'qseq'))}

	return($file_format,$qual_format);
      }

    #Open the input sequence file
    if(!(open(IN,$input_file)))
      {
	error("Unable to open sequnce file: [",
	      ($input_file eq '-' ? 'STDIN' : $input_file),"].  $!");
	return('','')
      }
    else
      {verbose("Determining file format of file: [",
	       ($input_file eq '-' ? 'STDIN' : $input_file),"].")}

    my @buffer   = ();
    my $line_num = 0;

    #Read the file to determine the sequence format
    while(getLine(*IN))
      {
	push(@buffer,$_);
	next if(/^\s*(#.*)?$/ && $file_format ne 'fastq');
	if(/^\s*>/)
	  {
	    $file_format = 'fasta';
	    last;
	  }
	elsif(/^\s*\@/)
	  {
	    $file_format = 'fastq';
	    last;
	  }
	elsif(/\t/)
	  {
	    $file_format = 'qseq';
	    last;
	  }
	else
	  {
	    error("Unrecognized file format: [$input_file].  Unable to parse ",
		  "first line of data: [$_]");
	    last;
	  }
      }

    putLines(*IN,@buffer);
    @buffer = ();

    close(IN);

    #If we know from the existence of a separate quality file that it's fasta
    if(defined($input_qual_file) && $input_qual_file ne '')
      {
	verbose("Determining quality format of file: [",
		($input_qual_file eq '-' ? 'STDIN' : $input_qual_file),"].");

	#Check to see if there are negative values (indicating phred64 quality
	#format)
	my $out = `grep [\-] $input_qual_file | grep -v '^[#>]' | wc -l`;
	chomp($out);
	$out =~ s/^\s*(\d+).*$/$1/s;

	#Assume phred33 (likely) if no negatives were found
	$qual_format = ($out ? 'phred64' : 'phred33');
      }
    else
      {
	#Open the sequence file to check out the embedded qualities
	if(!(open(IN,$input_file)))
	  {
	    error("Unable to open sequence file: [",
		  ($input_file eq '-' ? 'STDIN' : $input_file),"].  $!");
	    return('','')
	  }
	else
	  {verbose("Determining quality format of file: [$input_file].")}

	#If the file format is fastq
	my $first_line_seen = 0;
	if($file_format eq 'fastq')
	  {
	    my $phred64_vote_cnt = 0;
	    my $qual = 0;
	    while(getLine(*IN))
	      {
		push(@buffer,$_);
		#Skip empty lines
		next if(/^\s*$/);
		#Defline for the sequence allows these characters according to:
		#http://maq.sourceforge.net/fastq.shtml
		if(/^\@[^\n\r]+$/)
		  {
		    $first_line_seen = 1;
		    $qual = 0;
		  }
		#Defline for the qualities allows these chars according to:
		#http://maq.sourceforge.net/fastq.shtml
		elsif(/^\+[^\n\r]+$/)
		  {$qual = 1}
		#Guess the quality format based on the typical raw read quality
		#values defined here: http://en.wikipedia.org/wiki/FASTQ_format
		elsif($qual && /[!-:]/)
		  {
		    $qual_format = 'phred33';
		    last;
		  }
		#Guess the quality format based on the typical raw read quality
		#values defined here: http://en.wikipedia.org/wiki/FASTQ_format
		elsif($qual && /[J-h]/)
		  {
		    #Sanger/phred33 sequence could have higher qualities (J-h),
		    #but only in assemblies, not raw reads.  To be safe, we'll
		    #make sure 1000 lines have these values before setting the
		    #quality format.
		    $phred64_vote_cnt++;
		    if($phred64_vote_cnt >= 1000)
		      {
			$qual_format = 'phred64';
			last;
		      }
		  }
	      }

	    #We'll assume phred33 if all the characters are in the shared realm
	    #between formats since solexa is usually in qseq format
	    $qual_format = 'phred33' if($qual_format eq '');
	  }
	#Else if the file format is qseq (solexa)
	elsif($file_format eq 'qseq')
	  {
	    debug("Parsing Quality format.");

	    my $phred64_vote_cnt = 0;
	    while(getLine(*IN))
	      {
		push(@buffer,$_);
		#Skip empty lines
		next if(/^\s*$/);
		if((split(/\t/,$_))[9] =~ /[!-:]/)
		  {
		    $qual_format = 'phred33';
		    last;
		  }
		elsif((split(/\t/,$_))[9] =~ /[J-h]/)
		  {
		    #Sanger/phred33 sequence could have higher qualities (J-h),
		    #but only in assemblies, not raw reads.  To be safe, we'll
		    #make sure 1000 lines have these values before setting the
		    #quality format.
		    $phred64_vote_cnt++;
		    if($phred64_vote_cnt >= 1000)
		      {
			$qual_format = 'phred64';
			last;
		      }
		  }
	      }

	    #We'll assume phred64 if all the characters are in the shared realm
	    #between formats since this is an solexa file format
	    $qual_format = 'phred64' if($qual_format eq '');
	  }

	putLines(*IN,@buffer);
	close(IN);
      }

    debug("Returning [$file_format,$qual_format].");

    return($file_format,$qual_format);
  }

#Copied from seq-lib.pl on 9/9/04 so as to be independent -Rob
sub formatSequence
  {
    #1. Read in the parameters.
    my $sequence          = $_[0];
    my $chars_per_line    = $_[1];
    my $coords_left_flag  = defined($_[2]) ? $_[2] : 0;
    my $coords_right_flag = defined($_[3]) ? $_[3] : 0;
    my $start_coord       = $_[4];
    my $coords_asc_flag   = $_[5];
    my $coord_upr_bound   = $_[6];
    my $uppercase_flag    = $_[7];
    my $print_flag        = $_[8];
    my $nucleotide_flag   = $_[9];

    if(!defined($sequence) || $sequence eq '')
      {
	error("Sequence sent in is undefined.  Returning an empty string.")
	  if(!defined($sequence));
	return('');
      }

    my($formatted_sequence,
       $sub_string,
       $sub_sequence,
       $coord,
       $line_size_left,
       $lead_spaces,
       $line);
    my $max_num_coord_digits = 0;
    my $coord_separator      = '  ';
    my $tmp_sequence         = $sequence;
    $tmp_sequence            =~ s/\s+//g;
    $tmp_sequence            =~ s/<[^>]*>//g;
    my $seq_len              = length($tmp_sequence);

    #2. Error check the parameters and set default values if unsupplied.
    my $default_chars_per_line    = ''; #Infinity
    my $default_coords_left_flag  = 0;
    my $default_coords_right_flag = 0;
    my $default_start_coord       = (!defined($coords_asc_flag) ||
				     $coords_asc_flag ? 1 : $seq_len);
    my $default_coords_asc_flag   = 1;
    my $default_coord_upr_bound   = undef();  #infinity (going past 1 produces
    my $default_uppercase_flag    = undef();  #          negative numbers)
    my $default_print_flag        = 0;

    if(!defined($chars_per_line) || $chars_per_line !~ /^\d+$/)
      {
        if(defined($chars_per_line)  &&
	   $chars_per_line !~ /^\d+$/ && $chars_per_line =~ /./)
	  {print("WARNING:formatSequence.pl:formatSequence: Invalid ",
	         "chars_per_line: [$chars_per_line] - using default: ",
		 "[$default_chars_per_line]<BR>\n")}
        #end if(chars_per_line !~ /^\d+$/)
	$chars_per_line = $default_chars_per_line;
      }
    elsif(!$chars_per_line)
      {$chars_per_line = ''}
    #end if(!defined($chars_per_line) || $chars_per_line !~ /^\d+$/)
    if(!defined($coords_left_flag))
      {$coords_left_flag = $default_coords_left_flag}
    #end if(!defined(coords_left_flag))
    if(!defined($coords_right_flag))
      {$coords_right_flag = $default_coords_right_flag}
    #end if(!defined(coords_right_flag))
    if(!defined($start_coord) || $start_coord !~ /^\-?\d+$/)
      {
        if(defined($chars_per_line)  && defined($start_coord) &&
	   $start_coord !~ /^\d+$/ && $start_coord =~ /./ &&
           ($coords_left_flag || $coords_right_flag))
          {print("WARNING:formatSequence.pl:formatSequence: Invalid ",
                 "start_coord: [$start_coord] - using default: ",
                 "[$default_start_coord]\n")}
        #end if($start_coord !~ /^\d+$/)
        $start_coord = $default_start_coord;
      }
    #end if(!defined($start_coord) || $start_coord !~ /^\d+$/)
    if(!defined($coords_asc_flag))
      {$coords_asc_flag = $default_coords_asc_flag}
    #end if(!defined(coords_right_flag))
    if(defined($coord_upr_bound) && $coord_upr_bound !~ /^\d+$/)
      {undef($coord_upr_bound)}
    if(!defined($print_flag))
      {$print_flag = $default_print_flag}
    #end if(!defined($print_flag))

    if(defined($coord_upr_bound) && $start_coord < 1)
      {$start_coord = $coord_upr_bound + $start_coord}
    elsif($start_coord < 1)
      {$start_coord--}
    elsif(defined($coord_upr_bound) && $start_coord > $coord_upr_bound)
      {$start_coord -= $coord_upr_bound}

    #3. Initialize the variables used for formatting.  (See the DATASTRUCTURES
    #   section.)
    if($coords_asc_flag)
      {
        if(defined($coord_upr_bound) &&
           ($seq_len + $start_coord) > $coord_upr_bound)
          {$max_num_coord_digits = length($coord_upr_bound)}
        else
          {$max_num_coord_digits = length($seq_len + $start_coord - 1)}

        $coord = $start_coord - 1;
      }
    else
      {
        if(defined($coord_upr_bound) && ($start_coord - $seq_len + 1) < 1)
          {$max_num_coord_digits = length($coord_upr_bound)}
        elsif(!defined($coord_upr_bound) &&
              length($start_coord - $seq_len - 1) > length($start_coord))
          {$max_num_coord_digits = length($start_coord - $seq_len - 1)}
        else
          {$max_num_coord_digits = length($start_coord)}

        $coord = $start_coord + 1;
      }
    $line_size_left = $chars_per_line;
    $lead_spaces    = $max_num_coord_digits - length($start_coord);

    #5. Add the first coordinate with spacing if coords_left_flag is true.
    $line = ' ' x $lead_spaces . $start_coord . $coord_separator
      if($coords_left_flag);

    #6. Foreach sub_string in the sequence where sub_string is either a
    #   sub_sequence or an HTML tag.
    foreach $sub_string (split(/(?=<)|(?<=>)/,$sequence))
      {
        #6.1 If the substring is an HTML tag
        if($sub_string =~ /^</)
          #6.1.1 Add it to the current line of the formatted_sequence
          {$line .= $sub_string}
        #end if(sub_string =~ /^</)
        #6.2 Else
        else
          {
            $sub_string =~ s/\s+//g;

	    if($nucleotide_flag)
	      {
		my(@errors);
		(@errors) = ($sub_string =~ /([^ATGCBDHVRYKMSWNX])/ig);
		$sub_string =~ s/([^ATGCBDHVRYKMSWNX])//ig;
		if(scalar(@errors))
		  {print STDERR ("WARNING:formatSequence.pl:formatSequence:",
				 scalar(@errors),
				 " bad nucleotide characters were ",
				 "filtered out of your sequence: [",
				 join('',@errors),
				 "].\n")}
	      }

            #6.2.1 If the sequence is to be uppercased
            if(defined($uppercase_flag) && $uppercase_flag)
              #6.2.1.1 Uppercase the sub-string
              {$sub_string = uc($sub_string)}
            #end if(defined($uppercase_flag) && $uppercase_flag)
            #6.2.2 Else if the sequence is to be lowercased
            elsif(defined($uppercase_flag) && !$uppercase_flag)
              #6.2.2.1 Lowercase the sub-string
              {$sub_string = lc($sub_string)}
            #end elsif(defined($uppercase_flag) && !$uppercase_flag)

            #6.2.3 While we can grab enough sequence to fill the rest of a line
            while($sub_string =~ /(.{1,$line_size_left})/g)
              {
                $sub_sequence = $1;
                #6.2.3.1 Add the grabbed sequence to the current line of the
                #        formatted sequence
                $line .= $sub_sequence;
                #6.2.3.2 Increment the current coord by the amount of sequence
                #        grabbed
                my $prev_coord = $coord;
                if($coords_asc_flag)
                  {
                    $coord += length($sub_sequence);
                    if(defined($coord_upr_bound)      &&
                       $prev_coord <= $coord_upr_bound &&
                       $coord > $coord_upr_bound)
                      {$coord -= $coord_upr_bound}
                  }
                else
                  {
                    $coord -= length($sub_sequence);
                    if(defined($coord_upr_bound) &&
                       $prev_coord >= 1 && $coord < 1)
                      {$coord = $coord_upr_bound + $coord - 1}
                    elsif($prev_coord >= 1 && $coord < 1)
                      {$coord--}
                  }
                #6.2.3.3 If the length of the current sequence grabbed
                #        completes a line
                if((!defined($sub_sequence) && defined($line_size_left) &&
		   ($line_size_left !~ /^\d+$/ || $line_size_left == 0)) ||
		   (!defined($line_size_left) && defined($sub_sequence) &&
		    length($sub_sequence) == 0) ||
		   (!defined($sub_sequence) && !defined($line_size_left)) ||
		   (defined($sub_sequence) && defined($line_size_left) &&
		    (($line_size_left !~ /^\d+$/ &&
		      length($sub_sequence) == 0) ||
		     ($line_size_left =~ /^\d+$/ &&
		      length($sub_sequence) == $line_size_left))))
                  {
		    debug("coord is ",(defined($coord) ?
				       ($coord =~ /^\d+$/ ? 'an integer' :
					"a defined non-integer: [$coord]") :
				       'undefined'),
			  '.  max_num_coord_digits is ',
			  (defined($max_num_coord_digits) ?
			   ($max_num_coord_digits =~ /^\d+$/ ? 'an integer' :
			    "a defined non-integer: [$max_num_coord_digits]") :
			   'undefined'),'.');

                    $lead_spaces = $max_num_coord_digits - length($coord);
                    #6.2.3.3.1 Conditionally add coordinates based on the
                    #          coords flags
                    $line .= $coord_separator . ' ' x $lead_spaces . $coord
                      if($coords_right_flag);

                    #6.2.3.3.2 Add a hard return to the current line of the
                    #          formatted sequence
                    $line .= "\n";

                    #6.2.3.3.3 Add the current line to the formatted_sequence
                    $formatted_sequence .= $line;
                    #6.2.3.3.4 Print the current line if the print_flag is true
                    print $line if($print_flag);

                    #6.2.3.3.5 Start the next line
                    $lead_spaces = $max_num_coord_digits - length($coord+1);
                    $line = '';
                    $line = ' ' x $lead_spaces
                          . ($coords_asc_flag ? ($coord+1) : ($coord-1))
                          . $coord_separator
                      if($coords_left_flag);

                    #6.2.3.3.6 Reset the line_size_left (length of remaining
                    #          sequence per line) to chars_per_line
                    $line_size_left = $chars_per_line;
                  }
                #end if(length($sub_sequence) == $line_size_left)
                #6.2.3.4 Else
                else
                  #6.2.3.4.1 Decrement line_size_left (length of remaining
                  #          sequence per line) by the amount of sequence
                  #          grabbed
                  {
		    if(defined($sub_sequence) && length($sub_sequence) > 0)
		      {
			if(!defined($line_size_left) ||
			   $line_size_left !~ /^\d+$/)
			  {$line_size_left = 0}
			$line_size_left -= length($sub_sequence);
		      }
		  }
                #end 6.2.3.4 Else
              }
            #end while($sub_string =~ /(.{1,$line_size_left})/g)
          }
        #end 6.2 Else
      }
    #end foreach $sub_string (split(/(?=<)|(?<=>)/,$sequence))
    #7. Add the last coodinate with enough leadin white-space to be lined up
    #   with the rest coordinates if the coords_right_flag is true
    $lead_spaces = $max_num_coord_digits - length($coord);
    $line .= ' ' x $line_size_left . $coord_separator . ' ' x $lead_spaces
          . $coord
      if($coords_right_flag && $line_size_left != $chars_per_line);
    $line =~ s/^\s*\d+$coord_separator\s*$// if($coords_left_flag);

    #8. Add the ending PRE tag to the last line of the formatted sequence
    $line =~ s/\n*$/\n/s;

    #9. Add the last line to the formatted_sequence
    $formatted_sequence .= $line;
    #10. Print the last line if the print_flag is true
    print $line if($print_flag);

    if($coord < 1 && ($coords_left_flag || $coords_right_flag))
      {print("WARNING: The sequence straddles the origin.  Coordinates are ",
             "inaccurate.")}

    #11. Return the formatted_sequence
    return $formatted_sequence;
  }

#copied from seq-lib.pl on 11/8/2005
sub reverseComplement
  {
    #1. Read in the sequence parameter.
    my $sequence = $_[0];
    my @errors;
    if(@errors =
       ($sequence =~ /([^ATGCBVDHRYKMSWNatgcbvdhrykmswn\.\-\s\r])/isg))
      {print("WARNING:formatSequence.pl:ReverseComplement: Bad character(s) ",
	     "found: ['" . join("','",@errors) . "']\n")}
    #end if(@errors = ($sequence =~ /([^ATGCBVDHRYKM\s\r])/isg))
    #2. Translate the new_sequence.
    $sequence =~ tr/ATGCBVDHRYKMatgcbvdhrykm/TACGVBHDYRMKtacgvbhdyrmk/;
    #3. Reverse the new_sequence.
    $sequence = reverse($sequence);
    return $sequence;
  }

##
## This subroutine prints a description of the script and it's input and output
## files.
##
sub help
  {
    my $script = $0;
    my $lmd = localtime((stat($script))[9]);
    $script =~ s/^.*\/([^\/]+)$/$1/;

    #$software_version_number  - global
    #$created_on_date          - global
    $created_on_date = 'UNKNOWN' if($created_on_date eq 'DATE HERE');

    #Print a description of this program
    print << "end_print";

$script version $software_version_number
Copyright 2008
Robert W. Leach
Created: $created_on_date
Last Modified: $lmd
Center for Computational Research
701 Ellicott Street
Buffalo, NY 14203
rwleach\@ccr.buffalo.edu

* WHAT IS THIS: This script will convert to and from these sequence file
                formats: fastq, Illumina's qseq format, and fasta (both
                sequence and quality files).  You can output to multiple file
                formats at the same time by providing mulitple output file
                suffixes.  Also, it will convert between quality formats
                phred33 (i.e. sanger quality) and phred64 (solexa quality).

* FASTA SEQUENCE FORMAT EXAMPLE:

#comment about file
>sequence1
CTGATCGTGCTAGCTGTCGTAGTCG
CGTAGCGTCGTAGCGT
>sequence2
GCTATGCGGCTGATGCGCGTAGCGG
GTGTCGTAT

* FASTA QUALITY FORMAT EXAMPLE:

#comment about file
>sequence1
0 0 0 20 21 30 40 40 40 40 40 40 40 40 40 40 40 40 40 40 40 40 40 40 40
33 29 27 19 10 5 0 0 0 0 0 0 0 0 0 0
>sequence2
0 0 0 20 21 30 40 40 40 40 40 40 40 40 33 40 40 40 40 40 40 40 40 40 40
20 20 10 10 0 0 0 0 0

* FASTQ FORMAT EXAMPLE:

#comment about file
\@HWUSI-EAS1520:1:1:19704:5707#0/1
AAGAAAACATGAAGTATGGACATATCTTGAATGAGTTCTTTGAACAAAAAGTTGAAGAAACACTTAGATCGGAAGA
+HWUSI-EAS1520:1:1:19704:5707#0/1
^Y\\bZ`VR``VU^VP^ZZXZXZXX[bZ\\ZbZZX^ZXaT\\aVQJ\\Vbb\\YTPUVZVb\\Z]ZU\\L`BBBBBBBBBBBB
\@HWUSI-EAS1520:1:1:19704:17742#0/1
AGCGTGAAGTTTATCAACATTATGCCTTAAGTGCATTACCATTTCCAGAAAAAACAAAATTTGAAAAGATCGGAAG
+HWUSI-EAS1520:1:1:19704:17742#0/1
M\\T\\]QTUUUYU\\^]T^`]Z]^\\`Y^```]ba`aaYW\\\\TaT\\YYRRRQQ]ZZ`YW\\`\\Y]]ZUb]_]\\ZZXSZ`c

* QSEQ/SOLEXA FORMAT EXAMPLE:

#comment about file
HWUSI-EAS1520	0001	1	1	1046	13781	0	1	TTTCCTAACAGCACATTCTCAATCATTTCCGTAGTCCTTAACTTCGACCTAACCAAGATCCATGATCACTTCTGCT	BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB	0
HWUSI-EAS1520	0001	1	1	1046	4538	0	1	GAACATTGTGATTTCTTTGGTTTTGGAACTAATGATTTTAGGCGATTAGCATATGGTTTTCCACGTGTTGATGCAA	T`YLLbb\\b^cccTLLbQG_`]```M\\]^ZLL^T]^bbLKLaJLPaT`YTKQQW]aXJJJVb\\bb]KKZ_VS]_^^	0

* Supply "--show-quality-conversion" to see details on converting between quality formats.

end_print

    return(0);
  }

##
## This subroutine prints a usage statement in long or short form depending on
## whether "no descriptions" is true.
##
sub usage
  {
    my $no_descriptions = $_[0];

    my $script = $0;
    $script =~ s/^.*\/([^\/]+)$/$1/;

    #Grab the first version of each option from the global GetOptHash
    my $options = '[' .
      join('] [',
	   grep {$_ ne '-i'}           #Remove REQUIRED params
	   map {my $key=$_;            #Save the key
		$key=~s/\|.*//;        #Remove other versions
		$key=~s/(\!|=.|:.)$//; #Remove trailing getopt stuff
		$key = (length($key) > 1 ? '--' : '-') . $key;} #Add dashes
	   grep {$_ ne '<>'}           #Remove the no-flag parameters
	   keys(%$GetOptHash)) .
	     ']';

    print << "end_print";
USAGE: $script -i "input file(s)" $options
       $script $options < input_file
end_print

    if($no_descriptions)
      {print("`$script` for expanded usage.\n")}
    else
      {
        print << 'end_print';

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

end_print
      }

    return(0);
  }


##
## Subroutine that prints formatted verbose messages.  Specifying a 1 as the
## first argument prints the message in overwrite mode (meaning subsequence
## verbose, error, warning, or debug messages will overwrite the message
## printed here.  However, specifying a hard return as the first character will
## override the status of the last line printed and keep it.  Global variables
## keep track of print length so that previous lines can be cleanly
## overwritten.
##
sub verbose
  {
    return(0) unless($verbose);

    #Read in the first argument and determine whether it's part of the message
    #or a value for the overwrite flag
    my $overwrite_flag = $_[0];

    #If a flag was supplied as the first parameter (indicated by a 0 or 1 and
    #more than 1 parameter sent in)
    if(scalar(@_) > 1 && ($overwrite_flag eq '0' || $overwrite_flag eq '1'))
      {shift(@_)}
    else
      {$overwrite_flag = 0}

#    #Ignore the overwrite flag if STDOUT will be mixed in
#    $overwrite_flag = 0 if(isStandardOutputToTerminal());

    #Read in the message
    my $verbose_message = join('',grep {defined($_)} @_);

    $overwrite_flag = 1 if(!$overwrite_flag && $verbose_message =~ /\r/);

    #Initialize globals if not done already
    $main::last_verbose_size  = 0 if(!defined($main::last_verbose_size));
    $main::last_verbose_state = 0 if(!defined($main::last_verbose_state));
    $main::verbose_warning    = 0 if(!defined($main::verbose_warning));

    #Determine the message length
    my($verbose_length);
    if($overwrite_flag)
      {
	$verbose_message =~ s/\r$//;
	if(!$main::verbose_warning && $verbose_message =~ /\n|\t/)
	  {
	    warning('Hard returns and tabs cause overwrite mode to not work ',
		    'properly.');
	    $main::verbose_warning = 1;
	  }
      }
    else
      {chomp($verbose_message)}

    #If this message is not going to be over-written (i.e. we will be printing
    #a \n after this verbose message), we can reset verbose_length to 0 which
    #will cause $main::last_verbose_size to be 0 the next time this is called
    if(!$overwrite_flag)
      {$verbose_length = 0}
    #If there were \r's in the verbose message submitted (after the last \n)
    #Calculate the verbose length as the largest \r-split string
    elsif($verbose_message =~ /\r[^\n]*$/)
      {
	my $tmp_message = $verbose_message;
	$tmp_message =~ s/.*\n//;
	($verbose_length) = sort {length($b) <=> length($a)}
	  split(/\r/,$tmp_message);
      }
    #Otherwise, the verbose_length is the size of the string after the last \n
    elsif($verbose_message =~ /([^\n]*)$/)
      {$verbose_length = length($1)}

    #If the buffer is not being flushed, the verbose output doesn't start with
    #a \n, and output is to the terminal, make sure we don't over-write any
    #STDOUT output
    #NOTE: This will not clean up verbose output over which STDOUT was written.
    #It will only ensure verbose output does not over-write STDOUT output
    #NOTE: This will also break up STDOUT output that would otherwise be on one
    #line, but it's better than over-writing STDOUT output.  If STDOUT is going
    #to the terminal, it's best to turn verbose off.
    if(!$| && $verbose_message !~ /^\n/ && isStandardOutputToTerminal())
      {
	#The number of characters since the last flush (i.e. since the last \n)
	#is the current cursor position minus the cursor position after the
	#last flush (thwarted if user prints \r's in STDOUT)
	#NOTE:
	#  tell(STDOUT) = current cursor position
	#  sysseek(STDOUT,0,1) = cursor position after last flush (or undef)
	my $num_chars = sysseek(STDOUT,0,1);
	if(defined($num_chars))
	  {$num_chars = tell(STDOUT) - $num_chars}
	else
	  {$num_chars = 0}

	#If there have been characters printed since the last \n, prepend a \n
	#to the verbose message so that we do not over-write the user's STDOUT
	#output
	if($num_chars > 0)
	  {$verbose_message = "\n$verbose_message"}
      }

    #Overwrite the previous verbose message by appending spaces just before the
    #first hard return in the verbose message IF THE VERBOSE MESSAGE DOESN'T
    #BEGIN WITH A HARD RETURN.  However note that the length stored as the
    #last_verbose_size is the length of the last line printed in this message.
    if($verbose_message =~ /^([^\n]*)/ && $main::last_verbose_state &&
       $verbose_message !~ /^\n/)
      {
	my $append = ' ' x ($main::last_verbose_size - length($1));
	unless($verbose_message =~ s/\n/$append\n/)
	  {$verbose_message .= $append}
      }

    #If you don't want to overwrite the last verbose message in a series of
    #overwritten verbose messages, you can begin your verbose message with a
    #hard return.  This tells verbose() to not overwrite the last line that was
    #printed in overwrite mode.

    #Print the message to standard error
    print STDERR ($verbose_message,
		  ($overwrite_flag ? "\r" : "\n"));

    #Record the state
    $main::last_verbose_size  = $verbose_length;
    $main::last_verbose_state = $overwrite_flag;

    #Return success
    return(0);
  }

sub verboseOverMe
  {verbose(1,@_)}

##
## Subroutine that prints errors with a leading program identifier containing a
## trace route back to main to see where all the subroutine calls were from,
## the line number of each call, an error number, and the name of the script
## which generated the error (in case scripts are called via a system call).
##
sub error
  {
    return(0) if($quiet);

    #Gather and concatenate the error message and split on hard returns
    my @error_message = split(/\n/,join('',grep {defined($_)} @_));
    push(@error_message,'') unless(scalar(@error_message));
    pop(@error_message) if(scalar(@error_message) > 1 &&
			   $error_message[-1] !~ /\S/);

    $main::error_number++;
    my $leader_string = "ERROR$main::error_number:";

    #Assign the values from the calling subroutines/main
    my(@caller_info,$line_num,$caller_string,$stack_level,$script);
    if($DEBUG)
      {
	$script = $0;
	$script =~ s/^.*\/([^\/]+)$/$1/;
	@caller_info = caller(0);
	$line_num = $caller_info[2];
	$caller_string = '';
	$stack_level = 1;
	while(@caller_info = caller($stack_level))
	  {
	    my $calling_sub = $caller_info[3];
	    $calling_sub =~ s/^.*?::(.+)$/$1/ if(defined($calling_sub));
	    $calling_sub = (defined($calling_sub) ? $calling_sub : 'MAIN');
	    $caller_string .= "$calling_sub(LINE$line_num):"
	      if(defined($line_num));
	    $line_num = $caller_info[2];
	    $stack_level++;
	  }
	$caller_string .= "MAIN(LINE$line_num):";
	$leader_string .= "$script:$caller_string";
      }

    $leader_string .= ' ';

    #Figure out the length of the first line of the error
    my $error_length = length(($error_message[0] =~ /\S/ ?
			       $leader_string : '') .
			      $error_message[0]);

    #Put location information at the beginning of the first line of the message
    #and indent each subsequent line by the length of the leader string
    print STDERR ($leader_string,
		  shift(@error_message),
		  ($verbose &&
		   defined($main::last_verbose_state) &&
		   $main::last_verbose_state ?
		   ' ' x ($main::last_verbose_size - $error_length) : ''),
		  "\n");
    my $leader_length = length($leader_string);
    foreach my $line (@error_message)
      {print STDERR (' ' x $leader_length,
		     $line,
		     "\n")}

    #Reset the verbose states if verbose is true
    if($verbose)
      {
	$main::last_verbose_size  = 0;
	$main::last_verbose_state = 0;
      }

    #Return success
    return(0);
  }


##
## Subroutine that prints warnings with a leader string containing a warning
## number
##
sub warning
  {
    return(0) if($quiet);

    $main::warning_number++;

    #Gather and concatenate the warning message and split on hard returns
    my @warning_message = split(/\n/,join('',grep {defined($_)} @_));
    push(@warning_message,'') unless(scalar(@warning_message));
    pop(@warning_message) if(scalar(@warning_message) > 1 &&
			     $warning_message[-1] !~ /\S/);

    my $leader_string = "WARNING$main::warning_number:";

    #Assign the values from the calling subroutines/main
    my(@caller_info,$line_num,$caller_string,$stack_level,$script);
    if($DEBUG)
      {
	$script = $0;
	$script =~ s/^.*\/([^\/]+)$/$1/;
	@caller_info = caller(0);
	$line_num = $caller_info[2];
	$caller_string = '';
	$stack_level = 1;
	while(@caller_info = caller($stack_level))
	  {
	    my $calling_sub = $caller_info[3];
	    $calling_sub =~ s/^.*?::(.+)$/$1/ if(defined($calling_sub));
	    $calling_sub = (defined($calling_sub) ? $calling_sub : 'MAIN');
	    $caller_string .= "$calling_sub(LINE$line_num):"
	      if(defined($line_num));
	    $line_num = $caller_info[2];
	    $stack_level++;
	  }
	$caller_string .= "MAIN(LINE$line_num):";
	$leader_string .= "$script:$caller_string";
      }

    $leader_string .= ' ';

    #Figure out the length of the first line of the error
    my $warning_length = length(($warning_message[0] =~ /\S/ ?
				 $leader_string : '') .
				$warning_message[0]);

    #Put leader string at the beginning of each line of the message
    #and indent each subsequent line by the length of the leader string
    print STDERR ($leader_string,
		  shift(@warning_message),
		  ($verbose &&
		   defined($main::last_verbose_state) &&
		   $main::last_verbose_state ?
		   ' ' x ($main::last_verbose_size - $warning_length) : ''),
		  "\n");
    my $leader_length = length($leader_string);
    foreach my $line (@warning_message)
      {print STDERR (' ' x $leader_length,
		     $line,
		     "\n")}

    #Reset the verbose states if verbose is true
    if($verbose)
      {
	$main::last_verbose_size  = 0;
	$main::last_verbose_state = 0;
      }

    #Return success
    return(0);
  }


##
## Subroutine that gets a line of input and accounts for carriage returns that
## many different platforms use instead of hard returns.  Note, it uses a
## global array reference variable ($infile_line_buffer) to keep track of
## buffered lines from multiple file handles.
##
sub getLine
  {
    my $file_handle = $_[0];

    #Set a global array variable if not already set
    $main::infile_line_buffer = {} if(!defined($main::infile_line_buffer));
    if(!exists($main::infile_line_buffer->{$file_handle}))
      {$main::infile_line_buffer->{$file_handle}->{FILE} = []}

    #If this sub was called in array context
    if(wantarray)
      {
	#Check to see if this file handle has anything remaining in its buffer
	#and if so return it with the rest
	if(scalar(@{$main::infile_line_buffer->{$file_handle}->{FILE}}) > 0)
	  {
	    return(@{$main::infile_line_buffer->{$file_handle}->{FILE}},
		   map
		   {
		     #If carriage returns were substituted and we haven't
		     #already issued a carriage return warning for this file
		     #handle
		     if(s/\r\n|\n\r|\r/\n/g &&
			!exists($main::infile_line_buffer->{$file_handle}
				->{WARNED}))
		       {
			 $main::infile_line_buffer->{$file_handle}->{WARNED}
			   = 1;
			 warning('Carriage returns were found in your file ',
				 'and replaced with hard returns.');
		       }
		     split(/(?<=\n)/,$_);
		   } <$file_handle>);
	  }
	
	#Otherwise return everything else
	return(map
	       {
		 #If carriage returns were substituted and we haven't already
		 #issued a carriage return warning for this file handle
		 if(s/\r\n|\n\r|\r/\n/g &&
		    !exists($main::infile_line_buffer->{$file_handle}
			    ->{WARNED}))
		   {
		     $main::infile_line_buffer->{$file_handle}->{WARNED}
		       = 1;
		     warning('Carriage returns were found in your file ',
			     'and replaced with hard returns.');
		   }
		 split(/(?<=\n)/,$_);
	       } <$file_handle>);
      }

    #If the file handle's buffer is empty, put more on
    if(scalar(@{$main::infile_line_buffer->{$file_handle}->{FILE}}) == 0)
      {
	my $line = <$file_handle>;
	#The following is to deal with files that have the eof character at the
	#end of the last line.  I may not have it completely right yet.
	if(defined($line))
	  {
	    if($line =~ s/\r\n|\n\r|\r/\n/g &&
	       !exists($main::infile_line_buffer->{$file_handle}->{WARNED}))
	      {
		$main::infile_line_buffer->{$file_handle}->{WARNED} = 1;
		warning('Carriage returns were found in your file and ',
			'replaced with hard returns.');
	      }
	    @{$main::infile_line_buffer->{$file_handle}->{FILE}} =
	      split(/(?<=\n)/,$line);
	  }
	else
	  {@{$main::infile_line_buffer->{$file_handle}->{FILE}} = ($line)}
      }

    #Shift off and return the first thing in the buffer for this file handle
    return($_ = shift(@{$main::infile_line_buffer->{$file_handle}->{FILE}}));
  }

sub putLines
  {
    my $file_handle = shift(@_);
    my @lines       = @_;

    #If the global array variable doesn't exist, error out
    if(!exists($main::infile_line_buffer->{$file_handle}))
      {
	error("The file handle sent in has not been read from (using ",
	      "getLine) yet.  Unable to put line back.");
	return(1); #failure
      }

    unshift(@{$main::infile_line_buffer->{$file_handle}->{FILE}},@lines);
    return(0); #success
  }

##
## This subroutine allows the user to print debug messages containing the line
## of code where the debug print came from and a debug number.  Debug prints
## will only be printed (to STDERR) if the debug option is supplied on the
## command line.
##
sub debug
  {
    return(0) unless($DEBUG);

    $main::debug_number++;

    #Gather and concatenate the error message and split on hard returns
    my @debug_message = split(/\n/,join('',grep {defined($_)} @_));
    push(@debug_message,'') unless(scalar(@debug_message));
    pop(@debug_message) if(scalar(@debug_message) > 1 &&
			   $debug_message[-1] !~ /\S/);

    #Assign the values from the calling subroutine
    #but if called from main, assign the values from main
    my($junk1,$junk2,$line_num,$calling_sub);
    (($junk1,$junk2,$line_num,$calling_sub) = caller(1)) ||
      (($junk1,$junk2,$line_num) = caller());

    #Edit the calling subroutine string
    $calling_sub =~ s/^.*?::(.+)$/$1:/ if(defined($calling_sub));

    my $leader_string = "DEBUG$main::debug_number:LINE$line_num:" .
      (defined($calling_sub) ? $calling_sub : '') .
	' ';

    #Figure out the length of the first line of the error
    my $debug_length = length(($debug_message[0] =~ /\S/ ?
			       $leader_string : '') .
			      $debug_message[0]);

    #Put location information at the beginning of each line of the message
    print STDERR ($leader_string,
		  shift(@debug_message),
		  ($verbose &&
		   defined($main::last_verbose_state) &&
		   $main::last_verbose_state ?
		   ' ' x ($main::last_verbose_size - $debug_length) : ''),
		  "\n");
    my $leader_length = length($leader_string);
    foreach my $line (@debug_message)
      {print STDERR (' ' x $leader_length,
		     $line,
		     "\n")}

    #Reset the verbose states if verbose is true
    if($verbose)
      {
	$main::last_verbose_size = 0;
	$main::last_verbose_state = 0;
      }

    #Return success
    return(0);
  }


##
## This sub marks the time (which it pushes onto an array) and in scalar
## context returns the time since the last mark by default or supplied mark
## (optional) In array context, the time between all marks is always returned
## regardless of a supplied mark index
## A mark is not made if a mark index is supplied
## Uses a global time_marks array reference
##
sub markTime
  {
    #Record the time
    my $time = time();

    #Set a global array variable if not already set to contain (as the first
    #element) the time the program started (NOTE: "$^T" is a perl variable that
    #contains the start time of the script)
    $main::time_marks = [$^T] if(!defined($main::time_marks));

    #Read in the time mark index or set the default value
    my $mark_index = (defined($_[0]) ? $_[0] : -1);  #Optional Default: -1

    #Error check the time mark index sent in
    if($mark_index > (scalar(@$main::time_marks) - 1))
      {
	error('Supplied time mark index is larger than the size of the ',
	      "time_marks array.\nThe last mark will be set.");
	$mark_index = -1;
      }

    #Calculate the time since the time recorded at the time mark index
    my $time_since_mark = $time - $main::time_marks->[$mark_index];

    #Add the current time to the time marks array
    push(@$main::time_marks,$time)
      if(!defined($_[0]) || scalar(@$main::time_marks) == 0);

    #If called in array context, return time between all marks
    if(wantarray)
      {
	if(scalar(@$main::time_marks) > 1)
	  {return(map {$main::time_marks->[$_ - 1] - $main::time_marks->[$_]}
		  (1..(scalar(@$main::time_marks) - 1)))}
	else
	  {return(())}
      }

    #Return the time since the time recorded at the supplied time mark index
    return($time_since_mark);
  }

##
## This subroutine reconstructs the command entered on the command line
## (excluding standard input and output redirects).  The intended use for this
## subroutine is for when a user wants the output to contain the input command
## parameters in order to keep track of what parameters go with which output
## files.
##
sub getCommand
  {
    my $perl_path_flag = $_[0];
    my($command);

    #Determine the script name
    my $script = $0;
    $script =~ s/^.*\/([^\/]+)$/$1/;

    #Put quotes around any parameters containing un-escaped spaces or astericks
    my $arguments = [@$preserve_args];
    foreach my $arg (@$arguments)
      {if($arg =~ /(?<!\\)[\s\*]/ || $arg eq '')
	 {$arg = "'" . $arg . "'"}}

    #Determine the perl path used (dependent on the `which` unix built-in)
    if($perl_path_flag)
      {
	$command = `which $^X`;
	chomp($command);
	$command .= ' ';
      }

    #Build the original command
    $command .= join(' ',($0,@$arguments));

    #Note, this sub doesn't add any redirected files in or out

    return($command);
  }

##
## This subroutine checks for files with spaces in the name before doing a glob
## (which breaks up the single file name improperly even if the spaces are
## escaped).  The purpose is to allow the user to enter input files using
## double quotes and un-escaped spaces as is expected to work with many
## programs which accept individual files as opposed to sets of files.  If the
## user wants to enter multiple files, it is assumed that space delimiting will
## prompt the user to realize they need to escape the spaces in the file names.
## Note, this will not work on sets of files containing a mix of spaces and
## glob characters.
##
sub sglob
  {
    my $command_line_string = $_[0];
    unless(defined($command_line_string))
      {
	warning("Undefined command line string encountered.");
	return($command_line_string);
      }
    return(#If matches unescaped spaces
	   $command_line_string =~ /(?!\\)\s+/ &&
	   #And all separated args are files
	   scalar(@{[glob($command_line_string)]}) ==
	   scalar(@{[grep {-e $_} glob($command_line_string)]}) ?
	   #Return the glob array
	   glob($command_line_string) :
	   #If it's a series of all files with escaped spaces
	   (scalar(@{[split(/(?!\\)\s/,$command_line_string)]}) ==
	    scalar(@{[grep {-e $_} split(/(?!\\)\s+/,$command_line_string)]}) ?
	    split(/(?!\\)\s+/,$command_line_string) :
	    #Return the glob if a * is found or the single arg
	    ($command_line_string =~ /\*/ ? glob($command_line_string) :
	     $command_line_string)));
  }


sub getVersion
  {
    my $full_version_flag = $_[0];
    my $template_version_number = '1.40';
    my $version_message = '';

    #$software_version_number  - global
    #$created_on_date          - global
    #$verbose                  - global

    my $script = $0;
    my $lmd = localtime((stat($script))[9]);
    $script =~ s/^.*\/([^\/]+)$/$1/;

    if($created_on_date eq 'DATE HERE')
      {$created_on_date = 'UNKNOWN'}

    $version_message  = join((isStandardOutputToTerminal() ? "\n" : ' '),
			     ("$script Version $software_version_number",
			      " Created: $created_on_date",
			      " Last modified: $lmd"));

    if($full_version_flag)
      {
	$version_message .= (isStandardOutputToTerminal() ? "\n" : ' - ') .
	  join((isStandardOutputToTerminal() ? "\n" : ' '),
	       ('Generated using perl_script_template.pl ' .
		"Version $template_version_number",
		' Created: 5/8/2006',
		' Author:  Robert W. Leach',
		' Contact: robleach@ccr.buffalo.edu',
		' Company: Center for Computational Research',
		' Copyright 2008'));
      }

    return($version_message);
  }

#This subroutine is a check to see if input is user-entered via a TTY (result
#is non-zero) or directed in (result is zero)
sub isStandardInputFromTerminal
  {return(-t STDIN || eof(STDIN))}

#This subroutine is a check to see if prints are going to a TTY.  Note,
#explicit prints to STDOUT when another output handle is selected are not
#considered and may defeat this subroutine.
sub isStandardOutputToTerminal
  {return(-t STDOUT && select() eq 'main::STDOUT')}

#This subroutine exits the current process.  Note, you must clean up after
#yourself before calling this.  Does not exit is $ignore_errors is true.  Takes
#the error number to supply to exit().
sub quit
  {
    my $errno = $_[0];
    if(!defined($errno))
      {$errno = -1}
    elsif($errno !~ /^[+\-]?\d+$/)
      {
	error("Invalid argument: [$errno].  Only integers are accepted.  Use ",
	      "error() or warn() to supply a message, then call quit() with ",
	      "an error number.");
	$errno = -1;
      }

    debug("Exit status: [$errno].");

    exit($errno) if(!$ignore_errors || $errno == 0);
  }
