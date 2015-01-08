package McBain::WithGearmanXS;

# ABSTRACT: Load a McBain API as a Gearman worker

use warnings;
use strict;

use Carp;
use Gearman::XS qw(:constants);
use Gearman::XS::Worker;
use JSON::MaybeXS qw/JSON/;
use Try::Tiny;

our $VERSION = "3.000000";
$VERSION = eval $VERSION;

my $json = JSON->new->allow_blessed->convert_blessed;

=head1 NAME
 
McBain::WithGearmanXS - Load a McBain API as a Gearman worker

=head1 SYNOPSIS

	# write your API as you normally would, and create
	# a simple start-up script:

	#!/usr/bin/perl -w

	use warnings;
	use strict;
	use MyAPI;
	use McBain::WithGearmanXS;

	my $api = MyAPI->new;
	my $worker = McBain::WithGearmanXS->new($api);
	$worker->work('localhost', 4730);

=head1 DESCRIPTION

C<McBain::WithGearmanXS> turns your L<McBain> API into a L<Gearman worker|Gearman::XS::Worker>,
making it easy to consume your APIs with L<Gearman clients|Gearman::XS::Client>.

When your API is loaded, this module will traverse its routes, and create a queue for each
methods found. So, for example, if your API looks like this...

	package MyAPI;

	use McBain;

	get '/multiply' => (
		...
	);

	post '/divide' => (
		...
	);

...then the following queues will be created:

	GET:/multiply
	POST:/divide

The workers created receive payloads in JSON format, and convert them into the hash-refs your
API's methods expect to receive. Results are sent back to the clients in JSON as well. Note
that if an API method does not return a hash-ref, this runner module will automatically
turn it into a hash-ref to ensure that conversion into JSON will be possible. The created
hash-ref will have one key - holding the method's name, with whatever was returned from the
method as its value. For example, if method C<GET:/divide> in topic C</math> returns an
integer (say 7), then the client will get the JSON C<{ "GET:/math/divide": 7 }>.

=head2 CAVEATS

There are some disadvantages to using this runner:

=over

=item * Since a queue is created for every route and method in the API, C<McBain> cannot
intercept calls to routes that do not exist.

=item * You can't use regular expressions when defining queues. Well, you can, but they
won't work.

=item * Gearman provides no way of providing a detailed error message when jobs fail,
therefore all C<McBain> can do is indicate that the job has failed and no more.

=back

The first two I hope to overcome in a next version, or even a different runner, by creating
just one queue that simply forwards the requests to C<McBain>.

=head1 METHODS

=head2 work( [ $host, $port ] )

Connects the Gearman worker created by the module to the Gearman server
running at the host and port provided. If none are provided, C<localhost>
and C<4730> are used, respectively.

The method never returns, so that the worker listens for jobs continuously.

=cut

sub new {
	my ($class, $api) = @_;

	bless { api => $api }, $class;
}

sub work {
	my ($self, $host, $port) = @_;

	$host ||= 'localhost';
	$port ||= 4730;

	my $worker = Gearman::XS::Worker->new;

	$self->_register_functions($worker, $McBain::INFO{ref($self->{api})});

	$worker->add_server($host, $port) == GEARMAN_SUCCESS
		|| confess "Can't connect to gearman server at $host:$port, ".$worker->error;

	while (1) {
		$worker->work();
	}
}

sub _register_functions {
	my ($self, $worker, $info) = @_;

	foreach my $route (grep { !/^_/ } keys %$info) {
		foreach my $meth (grep { !/^_/ } keys %{$info->{$route}}) {
			my $namespace = $meth.':'.$route;
			$namespace =~ s!/$!!
				unless $route eq '/';
			unless (
				$worker->add_function($namespace, 0, sub {
					my $job = shift;

					try {
						my $path = $job->function_name;
						my $payload = $job->workload ? $json->decode($job->workload) : {};

						my $res = $self->{api}->call($path, $payload, __PACKAGE__);
						$res = { $path => $res }
							unless ref $res eq 'HASH';

						return $json->encode($res);
					} catch {
						$job->send_fail;
					};
				}, {}) == GEARMAN_SUCCESS
			) {
				confess "Can't register function $namespace, ".$worker->error;
			}
		}
	}
}

=head1 CONFIGURATION AND ENVIRONMENT
   
No configuration files are required.
 
=head1 DEPENDENCIES
 
C<McBain::WithGearmanXS> depends on the following CPAN modules:
 
=over

=item * L<Carp>
 
=item * L<Gearman::XS>

=item * L<JSON>
 
=back

=head1 INCOMPATIBILITIES WITH OTHER MODULES

None reported.

=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
C<bug-McBain-WithGearmanXS@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=McBain-WithGearmanXS>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc McBain::WithGearmanXS

You can also look for information at:

=over 4
 
=item * RT: CPAN's request tracker
 
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=McBain-WithGearmanXS>
 
=item * AnnoCPAN: Annotated CPAN documentation
 
L<http://annocpan.org/dist/McBain-WithGearmanXS>
 
=item * CPAN Ratings
 
L<http://cpanratings.perl.org/d/McBain-WithGearmanXS>
 
=item * Search CPAN
 
L<http://search.cpan.org/dist/McBain-WithGearmanXS/>
 
=back
 
=head1 AUTHOR
 
Ido Perlmuter <ido@ido50.net>
 
=head1 LICENSE AND COPYRIGHT
 
Copyright (c) 2013, Ido Perlmuter C<< ido@ido50.net >>.
 
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself, either version
5.8.1 or any later version. See L<perlartistic|perlartistic>
and L<perlgpl|perlgpl>.
 
The full text of the license can be found in the
LICENSE file included with this module.
 
=head1 DISCLAIMER OF WARRANTY
 
BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.
 
IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
 
=cut

1;
__END__
