package Net::LeanKit;
$Net::LeanKit::VERSION = '0.2';
# ABSTRACT: A perl library for Leankit.com

use strict;
use warnings;
use Carp;
use HTTP::Tiny;
use JSON::Any;
use URI::Escape;
use namespace::clean;


use Class::Tiny qw( email password account ), {
    boardIdentifiers => sub { +{} },
    defaultWipOverrideReason =>
      sub {'WIP Override performed by external system'}
};

sub BUILD {
    my ($self, $args) = @_;
    for my $req (qw/ email password account/) {
        croak "$req attribute required" unless defined $self->$req;
    }
}


sub client {
    my ($self, $method, $endpoint) = @_;
    my $auth = uri_escape(sprintf("%s:%s", $self->email, $self->password));
    my $url = sprintf('https://%s@%s.leankit.com/kanban/api/%s',
        $auth, $self->account, $endpoint);
    my $http  = HTTP::Tiny->new;
    my $j     = JSON::Any->new;
    my $res   = $http->request(uc $method, $url);
    my $j_res = $j->decode($res->{content});
    if ($j_res->{ReplyCode} == 200) {
        return $j_res->{ReplyData}->[0];
    }
    return +[];
}



sub getBoards {
    my ($self) = @_;
    my $res = $self->client('GET', 'boards');
    return $res;
}



sub getNewBoards {
    my ($self) = @_;
    return $self->client('GET', 'ListNewBoards');
}


sub getBoard {
    my ($self, $id) = @_;
    my $boardId = sprintf('boards/%s', $id);
    return $self->client('GET', $boardId);
}



sub getBoardByName {
    my ($self, $boardName) = @_;
    foreach my $board (@{$self->getBoards}) {
        next unless $board->{Title} =~ /$boardName/i;
        return $board;
    }
}


sub getBoardIdentifiers {
    my ($self, $boardId) = @_;

    # use cache
    if ($self->boardIdentifiers->{$boardId}) {
        return $self->boardIdentifiers->{$boardId};
    }

    my $board = sprintf('board/%s/GetBoardIdentifiers', $boardId);
    my $data = $self->client('GET', $board);
    $self->boardIdentifiers->{$boardId} = $data;
    return $self->boardIdentifiers->{$boardId};
}


sub getBoardBacklogLanes {
    my ($self, $boardId) = @_;
    my $board = sprintf("board/%s/backlog", $boardId);
    return $self->client('GET', $board);
}


sub getBoardArchiveLanes {
    my ($self, $boardId) = @_;
    my $board = sprintf("board/%s/archive", $boardId);
    return $self->client('GET', $board);
}


sub getBoardArchiveCards {
    my ($self, $boardId) = @_;
    my $board = sprintf("board/%s/archivecards", $boardId);
    return $self->client('GET', $board);
}


sub getNewerIfExists {
    my ($self, $boardId, $version) = @_;
    my $board = sprintf("board/%s/boardversion/%s/getnewerifexists", $boardId,
        $version);
    return $self->client('GET', $board);
}


sub getBoardHistorySince {
    my ($self, $boardId, $version) = @_;
    my $board = sprintf("board/%s/boardversion/%s/getboardhistorysince",
        $boardId, $version);
    return $self->client('GET', $board);
}


sub getBoardUpdates {
    my ($self, $boardId, $version) = @_;
    my $board =
      sprintf("board/%s/boardversion/%s/checkforupdates", $boardId, $version);
    return $self->client('GET', $board);
}


sub getCard {
    my ($self, $boardId, $cardId) = @_;
    my $board = sprintf("board/%s/getcard/%s", $boardId, $cardId);
    return $self->client('GET', $board);
}


sub getCardByExternalId {
    my ($self, $boardId, $externalCardId) = @_;
    my $board = sprintf("board/%s/getcardbyexternalid/%s",
        $boardId, uri_escape($externalCardId));
    return $self->client('GET', $board);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Net::LeanKit - A perl library for Leankit.com

=head1 VERSION

version 0.2

=head1 ATTRIBUTES

=head2 email

Login email

=head2 password

Password

=head2 account

Account name in which your account is under, usually a company name.

=head1 METHODS

=head2 client

Builds client url and sets up authentication with api service

=head2 getBoards

Returns list of boards

=head2 getNewBoards

Returns list of latest created boards

=head2 getBoard(INT id)

Gets leankit board by id

=head2 getBoardByName(STR boardName)

Finds a board by name

=head2 getBoardIdentifiers(INT boardId)

Get board identifiers

=head2 getBoardBacklogLanes(INT boardId)

Get board back log lanes

=head2 getBoardArchiveLanes(INT boardId)

Get board archive lanes

=head2 getBoardArchiveCards(INT boardId)

Get board archive cards

=head2 getNewerIfExists(INT boardId, INT version)

Get newer board version if exists

=head2 getBoardHistorySince(INT boardId, INT version)

Get newer board history

=head2 getBoardUpdates(INT boardId, INT version)

Get board updates

=head2 getCard(INT boardId, INT cardId)

Get specific card for board

=head2 getCardByExternalId(INT boardId, INT cardId)

Get specific card for board by an external id

=head1 AUTHOR

Adam Stokes <adamjs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Adam Stokes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT
WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER
PARTIES PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND,
EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE
SOFTWARE IS WITH YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME
THE COST OF ALL NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE LIABLE
TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE
SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH
DAMAGES.

=cut
