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
    all = []
    pages_count = response['lovedtracks']['totalPages'].to_i
    songs_count = response['lovedtracks']['total'].to_i
    all << response['lovedtracks']['track']

    (2..pages_count).each do |page|
      begin
        print "Getting #{page}/#{pages_count}\r"
        all << self.get_loved_tracks(options.merge(page: page))
      rescue StandardError => e
        puts e
      end
    end
    puts "#{all.count}/#{songs_count} tracks fetched!"
    all.flatten!
    raise "Only #{all.count}/#{songs_count} tracks fetched!" unless all.count == songs_count
    all
  end

  def loved_count(user)
    options = Lastfm::Util.build_options([user], [:user], [])
    request('getLovedTracks', options).xml['lovedtracks']['total'].to_i
  end
end

