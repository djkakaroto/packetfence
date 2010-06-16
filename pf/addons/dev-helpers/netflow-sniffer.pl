#!/usr/bin/perl

=head1 NAME

netflow-sniffer.pl - listen to netflow/IPFIX traffic and output it to stdout

=head1 SYNOPSIS

netflow-sniffer.pl -i <interface> -p <port> [options]

 Options:
   -d     Daemonize
   -v     Verbose, print info about headers and templates
   -h     Help

=cut

use strict;
use warnings;
use Getopt::Std;
use File::Basename qw(basename);
use POSIX qw(:signal_h);
use Log::Log4perl;
use Pod::Usage;
use Net::Flow qw(decode) ;
use IO::Socket::INET;

use constant INSTALL_DIR => '/usr/local/pf';

use lib INSTALL_DIR . "/lib";
use pf::db;
use pf::config;
use pf::util;

Log::Log4perl->init( INSTALL_DIR . "/conf/log.conf" );
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

my $script = basename($0);

POSIX::sigaction(
    &POSIX::SIGHUP,
    POSIX::SigAction->new('normal_sighandler', POSIX::SigSet->new(), &POSIX::SA_NODEFER)
) or $logger->logdie("$script: could not set SIGHUP handler: $!");

POSIX::sigaction(
    &POSIX::SIGTERM,
    POSIX::SigAction->new('normal_sighandler', POSIX::SigSet->new(), &POSIX::SA_NODEFER)
) or $logger->logdie("$script: could not set SIGTERM handler: $!");

POSIX::sigaction(
    &POSIX::SIGINT,
    POSIX::SigAction->new('normal_sighandler', POSIX::SigSet->new(), &POSIX::SA_NODEFER)
) or $logger->logdie("$script: could not set SIGINT handler: $!");


my @ORIG_ARGV = @ARGV;
my %args;
getopts( 'dhvi:p:', \%args );

my $daemonize = $args{d};
my $verbose = $args{v};
my $interface = $args{i};
my $port = $args{p};

pod2usage( -verbose => 1 ) if ( $args{h} || !($args{p} && $args{i}) );

daemonize() if ($daemonize);

$logger->info("initialized");

my $packet = undef;
my $TemplateArrayRef = undef;
my $templateReceivedFlag = 0;
#TODO: honor the -i parameter from CLI, wait do we really need that?
#I think its easier with an IP param (that we can grab from pf.conf)
my $sock = IO::Socket::INET->new(LocalPort => $port, Proto => 'udp')
  or $logger->logdie("Can't bind to UDP port $port. Netflow analysis stopped. OS error: $!");

$logger->info("Listening on UDP $port. Netflow analysis started.");

print "$script: bozo test\n";

while ($sock->recv($packet,1548)) {

    print "------------------------------------------------------------------------\n"; 
    print "received flow from: ". $sock->peerhost() . "\n";

    # forces re-init of variables
    my ($HeaderHashRef,$FlowArrayRef,$ErrorsArrayRef) = ();

    ($HeaderHashRef, $TemplateArrayRef, $FlowArrayRef, $ErrorsArrayRef)
         = Net::Flow::decode(\$packet, $TemplateArrayRef) ;

    # TODO: ERROR-HANDLING:
    # grep{ print "$_\n" }@{$ErrorsArrayRef} if( @{$ErrorsArrayRef} ) ;

    if (!$templateReceivedFlag && @{$TemplateArrayRef}) {
        print "Received the template. I can now interpret flows!\n";
        $templateReceivedFlag = 1;
    }

    if ($verbose) {
        print "\n- Header Information -\n" ;
        foreach my $Key ( sort keys %{$HeaderHashRef} ){
            printf " %s = %3d\n",$Key,$HeaderHashRef->{$Key} ;
        }
    
        foreach my $TemplateRef ( @{$TemplateArrayRef} ){
            print "\n- Template Information -\n" ;
     
            foreach my $TempKey ( sort keys %{$TemplateRef} ){
                if( $TempKey eq "Template" ){
                    printf "  %s = \n",$TempKey ;
                    foreach my $Ref ( @{$TemplateRef->{Template}}  ){
                        foreach my $Key ( keys %{$Ref} ){
                            printf "   %s=%s", $Key, $Ref->{$Key} ;
                        }
                        print "\n" ;
                    }
                }else{
                    printf "  %s = %s\n", $TempKey, $TemplateRef->{$TempKey} ;
                }
            }
        }
    }

    if (!@{$TemplateArrayRef}) {
        print "I have not received a template yet, I don't know how to parse the netflow\n";
    } else {

        print "------------------------------------------------------------------------\n";
        print "Size\t#pkts\tsrcip\t\tsrcport\tdstip\t\tdstport\tsrcmac\t\t\tdstmac\t\t\tnexthop\n";
    }

    foreach my $FlowRef ( @{$FlowArrayRef} ){
        #print "\n-- Flow Information --\n" ;
        my $tmp_start_time = hex(unpack("H*",$FlowRef->{22}));
        my $start_time = substr(($tmp_start_time),0,
        length($tmp_start_time) - 3) . substr(($tmp_start_time),
        length($tmp_start_time) - 3,3);
     
        my $tmp_end_time = hex(unpack("H*",$FlowRef->{21}));
        my $end_time = substr(($tmp_end_time), 0, length($tmp_end_time)-3).substr(($tmp_end_time), length($tmp_end_time) - 3,3);
        my $numberOfPackets = hex(unpack("H*",$FlowRef->{10}));
     
     
        my $nexthop = join('.', unpack('CCCC',$FlowRef->{15}));
     
        if($numberOfPackets ne "0"){
            my $data;
            $start_time += $HeaderHashRef->{"UnixSecs"} * 1000;
            $end_time += $HeaderHashRef->{"UnixSecs"} * 1000;
       
            # TODO there is a display bug if an IP is x.x.x.x the \t is not enough (ex: 8.8.4.4)
            #$data = "FLOW $start_time $end_time ";
            $data = hex(unpack("H*",$FlowRef->{1})) . "\t";                                # Size of Flow
            $data = $data . $numberOfPackets . "\t";                                       # Number of packets
            $data = $data . join('.', unpack('CCCC',$FlowRef->{8})) . "\t";                # Source Address
            $data = $data . hex(unpack("H*",$FlowRef->{7})) . "\t";                        # Source Port
            $data = $data . join('.', unpack('CCCC',$FlowRef->{12})) . "\t";               # Destination Address
            $data = $data . hex(unpack("H*",$FlowRef->{11})) . "\t";                       # Destination Port
            $data = $data . join(':', unpack('H2 H2 H2 H2 H2 H2', $FlowRef->{56})) . "\t"; # Source MAC Address
            $data = $data . join(':', unpack('H2 H2 H2 H2 H2 H2', $FlowRef->{57})) . "\t"; # Destination MAC Address
            $data = $data . join('.', unpack('CCCC',$FlowRef->{15})) . "\n";               # Next Hop Address
       
            print $data;
        }
    }
}


END {
    deletepid();

    # TODO free resources
}

exit(0);

sub daemonize {
    chdir '/' or $logger->logdie("Can't chdir to /: $!");
    open STDIN, '<', '/dev/null'
        or $logger->logdie("Can't read /dev/null: $!");
    my $log_file = "$install_dir/logs/$script";
    open STDOUT, '>>', $log_file
        or $logger->logdie("Can't write to $log_file: $!");

    defined( my $pid = fork )
        or $logger->logdie("$script: could not fork: $!");
    POSIX::_exit(0) if ($pid);
    if ( !POSIX::setsid() ) {
        $logger->warn("could not start a new session: $!");
    }
    open STDERR, '>&STDOUT' or $logger->logdie("Can't dup stdout: $!");
    createpid();
}

sub normal_sighandler {
    deletepid();
    $logger->logdie( "caught SIG" . $_[0] . " - terminating" );
}


=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2009,2010 Inverse inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

