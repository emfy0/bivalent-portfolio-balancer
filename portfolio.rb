require 'net/http'
require 'rexml/document'

def parse_value_from_valute(xml)
  xml.get_text('Value').to_s.gsub(',', '.').to_f
end

def parse_nominal_from_valute(xml)
  xml.get_text('Nominal').to_s.to_i
end

def currencies_from_xml(xml)
  doc = REXML::Document.new(xml)

  currencies = []
  doc.each_element('//Valute') do |element|
    currencies << {
      code: element.get_text('CharCode').to_s,
      course: (parse_value_from_valute(element) / parse_nominal_from_valute(element)).round(3),
      name: element.get_text('Name').to_s
    }
  end

  currencies << { code: 'RUB', course: 1, name: 'Рубль' }
end

def to_rub(currency)
  currency[:course] * currency[:amount]
end

def balance_dual_portfolio(currency1, currency2)
  sum = to_rub(currency1) + to_rub(currency2)

  difference = sum / 2 - to_rub(currency1)
  if difference.positive?
    { code: currency1[:code], to_buy: (difference / currency1[:course]).round(2) }
  else
    { code: currency2[:code], to_buy: (difference / currency2[:course]).abs.round(2) }
  end
end

URL = 'http://www.cbr.ru/scripts/XML_daily.asp'.freeze
response = Net::HTTP.get_response(URI.parse(URL))

currencies = currencies_from_xml(response.body)

if ARGV[0] == '--help'
  currencies.each do |e|
    puts "*  #{e[:code]} (#{e[:name]})"
  end
else
  puts <<~TEXT
    Чтобы посмотреть список поддрживаемых валют
    запустите программу с флагом --help
  TEXT
end

puts 'Введите код первой желаемой валюты'
code = $stdin.gets.chomp.upcase while currencies.select { |e| e[:code] == code }.empty?

puts 'Введите ее количество'
amount = $stdin.gets.to_i

currency1 = {
  code: code,
  course: currencies.select { |e| e[:code] == code }[0][:course],
  amount: amount
}

code = '-1'
puts 'Введите код второй желаемой валюты'
code = $stdin.gets.chomp.upcase while currencies.select { |e| e[:code] == code }.empty?

puts 'Введите ее количество'
amount = $stdin.gets.to_i

currency2 = {
  code: code,
  course: currencies.select { |e| e[:code] == code }[0][:course],
  amount: amount
}

currency_to_buy = balance_dual_portfolio(currency1, currency2)

puts <<~TEXT
  \nКурс первой валюты(#{currency1[:code]}): #{currency1[:course].round(2)} RUB
  Курс второй валюты(#{currency2[:code]}): #{currency2[:course].round(2)} RUB
  Вам нужно купить #{currency_to_buy[:to_buy]} #{currency_to_buy[:code]}
TEXT
