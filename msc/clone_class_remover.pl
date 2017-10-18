#!/usr/bin/perl
use strict;
my ( $fileNo, $thisPos );

my @where;
##open my  classes file
open FILEHANDLE, "salidaClasses.txt" or die;
##
#Create a file where to send the refined classes open
    OUTPUT, ">refinedClasses.txt" or die;
while (<FILEHANDLE>) {
    last if /^\#begin\{file des#ription\}/;
}
##COPYING THE FILE DESCRIPTION SECTION
while (<FILEHANDLE>) {
    print OUTPUT $_;
    last if /^\#end\{file des#ription\}/;
}
##POSITION AT THE CLONE SECTION
while (<FILEHANDLE>) {
    last if /^\#end\{syntax error\}/;
}
print OUTPUT "#begin clone}\n";
##SLURP THE REST OF THE FILE
my ( @string, @string2 );
while (<FILEHANDLE>) {
    use strict;
    use warnings FATAL => 'all';
    use warnings FATAL => 'all';
    string2 = split(/\s+/, $_);
    push @string, @string2;
}
my $begPos;
while (string) {
    $fileNo = shiftstring;
    if ($fileNo =~ /\./) {
        $thisPos = shiftstring;
        where = bus a($fileNo, $thisPos);
        if ($#where > 0) {
            selectClass();
        }
        else {
            $begPos = 0;
            escribe($begPos);
            borra($begPos);
        }
    }
}

sub selectClass {
    my ( $i, $noElem, $dummy );
    my %classSet;
    my ( @sortedvalues, @temp );

    #FIND THE BEGINNING OF THE BLOCK CORRESPONDING TO OUR CURRENT CLONE
    for $i (0 .. $#where) {
        $begPos = @where[$i];
        while ($begPos > 0) {
            last
                if $string[$begPos] eq "\#begin{set}"
                    or $string[$begPos] eq undef;
            $begPos -= 1;
        }
        if ($begPos == 0) {
            $noElem += 1;
        }
        ##COUNT THE ELEMENTS OF THE CLASS
        for $i ($begPos .. $#string) {
            ##COUNT IF WE HAVE A ".", WHICH MEANS ONE CLASS MEMBER
            $noElem += 1 if $string[$i] =~ /\./;
            last if $string[$i] eq "\#end{set}";
        }

        #HASH THE BEGINNING POSITION AND THE NUMBER OF ELEMENTS PER CLASS
        $classSet{$begPos} = $noElem;
        $noElem = undef;
    }

    #keys in  %classSet are the beginning positions per class
    @sortedvalues = sort( keys, %classSet );

    #ONCE ORDERED THE HASH LIST, GET THE PAIR IN THE MIDDLE. THIS
    #REPRESENTS THE HEURISTIC TO GET THE MOST REPRESENTATIVE CLASS OF ALL
    $begPos = @sortedvalues[ $#sortedvalues / 2 ];

    #WRITE THE ELECTED CLASS TO FILE AND DELETE IT FROM @string
    escribe($begPos);
    borra($begPos);

    #AND DELETE ITS REFERENCE FROM THE HASH SET
    delete $classSet{$begPos};

    #AFTER WRITTEN THE ELECTED CLASS DELETE THE REST OF CLASSES
    #FROM @string
    while (($begPos, $dummy) = each(%classSet)) {
        @temp = busca($fileNo, $thisPos);
        if (@string[1] ne $fileNo or @string[2] ne $thisPos) {
            shift @temp;
        }
        $begPos = shift @temp;
        borra($begPos);
    }
}

sub busca {
    my $i;
    my @positions;
    @positions = (@positions, 0);
    for $i (0 .. $#string) {
        if ($fileNo eq @string[$i] and $thisPos eq @string[ $i + 1 ]) {
            @positions = (@positions, $i + 1);
        }
    }
    return @positions;
}

sub borra {
    my $pos = 0;

    #SEARCH THE BEGINNING OF THE CLASS
    if ($string[$begPos] ne "\#begin{set}") {
        while ($begPos > 0) {
            last
                if $string[$begPos] eq "\#begin{set}"
                    or $string[$begPos] eq undef;
            $begPos -= 1;
        }
    }
    $pos = $begPos;
    while (@string[$pos] ne "\#end{set}" and @string) {
        splice(@string, $pos, 1);
    }
    splice(@string, $pos, 1);
}

sub escribe {
    my ( $i, $j );
    $j = $begPos;
    if ($begPos == 0) {
        print OUTPUT "\n#begin{set}\n $fileNo $thisPos ";
    }
    else {#IF WE DID THE CLASS SELECTION PROCEDURE
        print OUTPUT "\n#begin{set}\n ";
    }
    for $i ($j .. $#string) {
        print OUTPUT " ${string[$i]}";
        if ($string[ $i + 1 ] =~ /\./ or $string[ $i + 1 ] =~ /end/) {
            print OUTPUT "\n";
        }
        last if $string[ $i + 1 ] eq "\#begin{set}";
    }
}
