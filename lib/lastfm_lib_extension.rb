class Lastfm::MethodCategory::User < Lastfm::MethodCategory::Base
  def get_all_loved_tracks(*args)
    method = 'getLovedTracks'
    response = if args.any?
                 options = Lastfm::Util.build_options(args, [:user], [])
                 request(method, options)
               else
                 request_with_authentication(method)
               end
    response = response.xml
    all_responses = []
    pages_count = response['lovedtracks']['totalPages'].to_i
    songs_count = response['lovedtracks']['total'].to_i
    all_responses << response['lovedtracks']['track']

    (2..pages_count).each do |page|
      begin
        print "Loading page #{page}/#{pages_count}\r"
        all_responses << self.get_loved_tracks(options.merge(page: page))
      rescue StandardError => e
        puts e
      end
    end
    all_responses.flatten!
    puts "#{all_responses.count}/#{songs_count} tracks received!"
    raise "Only #{all_responses.count}/#{songs_count} tracks received!" unless all_responses.count == songs_count
    all_responses
  end

  def loved_count(user)
    options = Lastfm::Util.build_options([user], [:user], [])
    request('getLovedTracks', options).xml['lovedtracks']['total'].to_i
  end
end