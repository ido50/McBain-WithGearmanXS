package Mendoza;

use McBain::Mo;
use McBain 3.000000;

has 'status';

get '/' => (
	description => 'Returns the name of the API',
	cb => sub {
		return 'MEN-DO-ZAAAAAAAAAAAAA!!!!!!!!!!!';
	}
);

get '/status' => (
	description => 'Returns the status of the API',
	cb => sub { shift->status }
);

sub BUILD { shift->status('ALL IS WELL') }

1;
__END__
