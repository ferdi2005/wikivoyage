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

categorie = [ "Mostre", "Festival", "Conflitti", "Manifestazioni", "Trasporti", "COVID%2D19"]

pubblicati = HTTParty.get("https://petscan.wmflabs.org/?combination=union&project=wikinews&negcats=Articoli%20archiviati&labels%5Fyes=&templates%5Fyes=&pagepile=&depth=10&wpiu=any&cb%5Flabels%5Fyes%5Fl=1&namespace%5Fconversion=keep&sitelinks%5Fyes=&min%5Fredlink%5Fcount=1&search%5Fwiki=&language=it&ores%5Fprediction=any&categories=#{categorie.join("%0D%0A")}&min%5Fsitelink%5Fcount=&show%5Fredirects=both&smaller=&templates%5Fany=&outlinks%5Fany=&maxlinks=&output%5Flimit=&doit=Do%20it%21&referrer%5Fname=&interface%5Flanguage=it&active%5Ftab=tab%5Fcategories&since%5Frev0=&subpage%5Ffilter=either&regexp%5Ffilter=&ores%5Fprob%5Ffrom=&page%5Fimage=any&wikidata%5Fsource%5Fsites=&larger=&edits%5Bflagged%5D=both&search%5Fmax%5Fresults=500&labels%5Fno=&ores%5Fprob%5Fto=&search%5Fquery=&wikidata%5Flabel%5Flanguage=&max%5Fsitelink%5Fcount=&templates%5Fno=Notizia%20per%20Wikivoyage&outlinks%5Fno=&labels%5Fany=&show%5Fdisambiguation%5Fpages=both&search%5Ffilter=&cb%5Flabels%5Fno%5Fl=1&sitelinks%5Fany=&before=&links%5Fto%5Fany=&ns%5B0%5D=1&outlinks%5Fyes=&cb%5Flabels%5Fany%5Fl=1&minlinks=&sparql=&after=#{(Date.today - 180).strftime("%Y%m%d")}&common%5Fwiki%5Fother=&source%5Fcombination=&format=json&common%5Fwiki=auto&show%5Fsoft%5Fredirects=both&output%5Fcompatability=catscan&max%5Fage=&links%5Fto%5Fall=&edits%5Bbots%5D=both&sitelinks%5Fno=&langs%5Flabels%5Fyes=&wikidata%5Fitem=no&ores%5Ftype=any&edits%5Banons%5D=both&links%5Fto%5Fno=&langs%5Flabels%5Fno=&manual%5Flist=&manual%5Flist%5Fwiki=&referrer%5Furl=&sortorder=descending&wikidata%5Fprop%5Fitem%5Fuse=&langs%5Flabels%5Fany=&sortby=date").to_h["*"][0]["a"]["*"]

# Per ogni articolo ottengo il contenuto
pubblicati.map do |pubblicato|
    content = client.query(prop: :revisions, rvprop: :content, titles: pubblicato["title"], rvlimit: 1)["query"]["pages"][pubblicato["id"].to_s]["revisions"][0]["*"]
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
