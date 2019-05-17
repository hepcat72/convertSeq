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
