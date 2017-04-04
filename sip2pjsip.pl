#!/usr/bin/env perl
use strict;
use warnings;
use v5.010;
use autodie;
use DBI;

my %db = (
  user => 'root',
  pass => '',
  db   => 'asterisk',
);
my $dsn = "DBI:mysql:database=$db{db};host=localhost";
my $dbh = DBI->connect($dsn, $db{user}, $db{pass}, {RaiseError => 1, AutoCommit => 0 });

sub insert_in_db {
  my $table = shift;
  my @values = @_;

  my $query = "INSERT INTO $table VALUES(" . join(',', @values) .");";
  print $query;
}

sub read_lines_from_db {
  my $query = "SELECT extension,secret,callerid,context FROM devices WHERE context NOT LIKE 'mor%' and extension REGEXP '^[0-9][0-9]+'";

  my $sth = $dbh->prepare($query);
  $sth->execute();
  open (my $pjsip_file, '>', 'pjsip_from_db.conf') or die "Could not open file";
  while( my @row = $sth->fetchrow_array()) {
    print_pjsip_extension($pjsip_file, $row[0], $row[1], "callerid=" . $row[2] . "\n", $row[3] . '_phone');
  }
}
  

sub print_pjsip_extension {
  my $fh = shift;
  my $extension = shift;
  my $password = shift;
  my $callerid_line = shift;
  my $endpoint_template = shift;
  
  # Print Endpoint config
  print $fh "[$extension]($endpoint_template)\n";
  print $fh "type=endpoint\n";
  print $fh "auth=auth$extension\n";
  print $fh "aors=$extension\n";
  print $fh $callerid_line;
  # Print Auth config
  print $fh "[auth$extension](auth-userpass)\n";
  print $fh "username=$extension\n";
  print $fh "password=$password\n";
  # Print Aors config
  print $fh "[$extension](aor-single-reg)\n";

  print $fh "\n";

}

if ($ARGV[0] =~ /^db$/i) {
  read_lines_from_db();
  exit(0);
}

$ARGV[0] =~ /sip_(\w+).conf$/;
my $reseller = $1 or die "Could not extract reseller from filename";

say $reseller;

my $destination_filename = $ARGV[0];
$destination_filename =~ s/sip/pjsip/;
say $destination_filename;

open (my $sip_file, '<', $ARGV[0]) or die "Could not open file $ARGV[0]";

open (my $pjsip_file, '>', $destination_filename) or die "Could not open file $destination_filename";

my $endpoint_template_name = "${reseller}_endpoint";

print $pjsip_file "[$endpoint_template_name](!,endpoint-basic)\n";
print $pjsip_file "context=$reseller\n\n";

my $extension;
my $secret;
my $callerid_line;

while (<$sip_file>) {
  if (/^\[(\d+)\]\(\w+_phone\)$/) {
    $extension = $1;
  } elsif (/^secret=(\w+)$/) {
    $secret = $1;
  } elsif (/^callerid=/) {
    $callerid_line = $_;
  } elsif (/^$/ and $extension) {
    print "$extension $secret\n";
    print $callerid_line;
    print_pjsip_extension($pjsip_file, $extension, $secret, $callerid_line, $endpoint_template_name);
  }

}


close($sip_file);
close($pjsip_file);
