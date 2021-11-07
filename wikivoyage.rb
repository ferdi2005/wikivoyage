require 'mediawiki_api'
require 'date'
require 'wikinotizie'
require 'httparty'

if !File.exist? "#{__dir__}/.config"
    puts 'Inserisci username:'
    print '> '
    username = gets.chomp
    puts 'Inserisci password:'
    print '> '
    password = gets.chomp
    File.open("#{__dir__}/.config", "w") do |file| 
      file.puts username
      file.puts password
    end
end
userdata = File.open("#{__dir__}/.config", "r").to_a

client = MediawikiApi::Client.new 'https://it.wikinews.org/w/api.php'
client.log_in "#{userdata[0].strip}", "#{userdata[1].strip}"

pubblicati = [] 
["Categoria:Mostre", "Categoria:Festival", "Categoria:Conflitti", "Categoria:Manifestazioni", "Categoria:Trasporti"].each do |cat|
 pubblicati += client.query(list: :categorymembers, cmtitle: cat, cmsort: :timestamp, cmdir: :desc, cmlimit: 50)["query"]["categorymembers"]
end

pubblicati -= client.query(list: :categorymembers, cmtitle: "Categoria:Articoli archiviati", cmsort: :timestamp, cmdir: :desc, cmlimit: 50)["query"]["categorymembers"]


# Per ogni articolo ottengo il contenuto
pubblicati.map do |pubblicato|
    content = client.query(prop: :revisions, rvprop: :content, titles: pubblicato["title"], rvlimit: 1)["query"]["pages"]["#{pubblicato["pageid"]}"]["revisions"][0]["*"]
    # Processo il contenuto con la gem Wikinotizie
    # content = [content, match, data, giorno, rubydate, with_luogo, luogo]
    parsed = Wikinotizie.parse(content)
    unless parsed == false
        data = parsed[4]
        next if data < (Date.today - 180)
        puts "Aggiorno #{pubblicato["title"]}"
        template = "{{Notizia per Wikivoyage|anno=#{data.year}|mese=#{data.month}|giorno=#{data.day}}}" 
        content += "\n#{template}"
        client.edit(title: pubblicato["title"], text: content, summary: "Aggiungo template per Wikivoyage")
    end
end
