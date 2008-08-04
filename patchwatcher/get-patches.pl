#!/usr/bin/perl
# Get and remove all complete patches/patch series from the specified mailbox
# Drop any patch older than three days 
# Also delete any non-patch email encountered
# Argument is number of first patch to output.
# Patches are output as %d.patch in utf-8 format.

# Dan Kegel 2008

use strict;
use warnings;
use Mail::POP3Client;
use MIME::Parser;
use Encode qw/decode/; 

my $pop = new Mail::POP3Client(
                 USER     => $ENV{"PATCHWATCHER_USER"},
                 PASSWORD => $ENV{"PATCHWATCHER_PASSWORD"},
                 HOST     => $ENV{"PATCHWATCHER_HOST"}
);

## Initialize stuff for MIME::Parser;
# TODO: stop using outputdir
my $outputdir = "./mimemail";
my $parser = new MIME::Parser;
$parser->output_dir($outputdir);

my $curpatch = $ARGV[0];
if ($curpatch eq "") {
    print "Usage: perl get-patches.pl starting-patch-number\n";
    exit(1);
}

my $patches_written = 0;

sub output_patch
{
    my $header = $_[0];
    my $body = $_[1];
    open FILE, "> $curpatch.patch" || die "can't create $curpatch.patch";
    binmode FILE, ":utf8";
    $curpatch++;
    $patches_written++;

    print FILE "From: ". decode('MIME-Header', $header->get('From'));
    print FILE "Subject: ".$header->get('Subject');
    print FILE "Date: ".$header->get('Date');
    print FILE "\n";
    print FILE $body;

    close FILE;
}

# Is a body string a patch?
sub is_patch
{
    my $body = $_[0];

    return $body =~ m/^diff|\ndiff|^--- |\n--- /;
}

sub netascii_to_host
{
   my $body = $_[0];

   $body =~ s/\015//g;
   return $body;
}

# Given an index into the mailbox, return a pair
# ($head_object, $message_as_plaintext)
# Flattens attachments.
# FIXME: currently only includes the patch part of the body
sub retrieve_message
{
   my $index = $_[0];

   my $msg = $pop->HeadAndBody( $index );
   my $entity = $parser->parse_data($msg);

   $entity->make_singlepart;

   # Convert from netascii to ascii
   if ($entity->parts < 2) {
        return ($entity->head, netascii_to_host($entity->bodyhandle->as_string));
   } else {
        my $part = 1;
        foreach ($entity->parts) {
            if (defined($_->bodyhandle) && is_patch($_->bodyhandle->as_string)) {
                return ($entity->head, netascii_to_host($_->bodyhandle->as_string));
            }
        }
   }
   return ($entity->head, undef);
}

my $series_sender = "";
my $series_num_patches;
my @series_headers;
my @series_bodies;
my @series_indices;

sub consume_series_patch
{
    my $header = $_[0];
    my $body = $_[1];
    my $index = $_[2];
    my $which_patch = $_[3];
    my $num_patches = $_[4];

    my $sender = decode('MIME-Header', $header->get('From'));

    if ($series_sender eq "") {
       #print "Starting series; sender $sender, num_patches $num_patches, subject ".$header->get('Subject')."\n";
       $series_sender = $sender;
       $series_num_patches = $num_patches;
    }

    if ($series_sender ne $sender) {
        #print "Ignoring series for now, will try later; sender $sender, num_patches $num_patches, subject ".$header->get('Subject')."\n";
        # can't handle multiple series at once just yet, let it sit
        return;
    }
    #print "Saving patch $which_patch\n";
    $series_headers[$which_patch] = $header;
    $series_bodies[$which_patch] = $body;
    $series_indices[$which_patch] = $index;

    # Is the series complete?
    my $j;
    for ($j=1; $j <= $series_num_patches; $j++) {
        last if (! defined($series_indices[$j]));
    }
    if ($j == $series_num_patches+1) {
        # Yes!  Output them all.
        for ($j=1; $j <= $series_num_patches; $j++) {
            #print "Outputting patch $j of $series_num_patches\n";
            output_patch($series_headers[$j], $series_bodies[$j]);
            #$pop->Delete( $series_indices[$j] );
        }
        @series_headers = ();
        @series_bodies = ();
        @series_indices = ();
        $series_sender = "";
        $series_num_patches = "";
    }
}

sub consume_patch
{
    my $header = $_[0];
    my $body = $_[1];
    my $index = $_[2];

    if ($header->get('Subject') !~ /(\d+)\/(\d+)/) {
        output_patch($header, $body);
        #$pop->Delete( $index );
    } else {
        # part of sequence 
        my $which_patch = $1;
        my $num_patches = $2;
        if ($which_patch == 0) {
            # Zeroth patch in series is supposed to be just explanation?
            #$pop->Delete( $index );
        } else {
            # Patches that are part of a series get special treatment
            consume_series_patch($header, $body, $index, $which_patch, $num_patches);
        }
    }
}

my $i;
for ($i = 1; $i <= $pop->Count(); $i++) {
    my ($head, $body) = retrieve_message($i);

    # Delete messages without body?
    if (!defined($body)) {
        #print "no body?\n";
        ; # $pop->Delete( $i );
        next;
    }

    # Delete non-patches
    if (! is_patch($body)) {
        ; # $pop->Delete( $i );
        next;
    }

    # TODO: delete patches older than three days
    #my $date = $head->get('Date');
    #if ($today - $date  > 3 days) {
    #    $pop->Delete( $i );
    #   next;
    #}
 
    consume_patch($head, $body, $i);
}
$pop->Close();

if ($patches_written > 0) {
    exit(0);
} else {
    exit(1);
}

