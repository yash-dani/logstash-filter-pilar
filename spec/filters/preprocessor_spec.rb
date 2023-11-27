# frozen_string_literal: true

require 'rspec'
require_relative '../spec_helper'
require 'logstash/filters/preprocessor'
require 'logstash/filters/gramdict'

describe Preprocessor do
  let(:gram_dict) { double('GramDict') }
  let(:regexes) { [/\d{3}-\d{2}-\d{4}/] }
  let(:logformat) { '<date> <time> <message>' }
  let(:content_specifier) { 'message' }
  let(:preprocessor) { Preprocessor.new(gram_dict, regexes, logformat, content_specifier) }

  describe '#regex_generator' do
    it 'generates a regex based on log format' do
      logformat = '<date> <time> <message>'
      regex = preprocessor.send(:regex_generator, logformat)
      expect(regex).to be_a(Regexp)
      expect('2023-01-01 10:00:00 Sample Log Message').to match(regex)
    end
  end

  describe '#mask_log_event' do
    it 'masks sensitive data in log event' do
      log_event = '2023-01-01 10:00:00 Sensitive Data'
      masked_event = preprocessor.mask_log_event(log_event)
      expect(masked_event).to include('<*>')
    end

    it 'does not alter log event without sensitive data' do
      log_event = 'Regular Log Message'
      masked_event = preprocessor.mask_log_event(log_event)
      expect(masked_event).to eq(" #{log_event}")
    end

    it 'utilizes regexes in @regexes to mask patterns in log event' do
      log_event = 'Error reported 2023-01-01 10:00:00 with ID 123-45-6789'
      masked_event = preprocessor.mask_log_event(log_event)
      expect(masked_event).not_to include('123-45-6789')
      expect(masked_event).to include('<*>')
    end
  end

  describe '#token_spliter' do
    it 'splits a log line into tokens when a match is found' do
      log_line = '2023-01-01 10:00:00 Sample Log Message'
      tokens = preprocessor.token_spliter(log_line)
      expect(tokens).to be_an(Array)
      expect(tokens).to eq(%w[Sample Log Message])
    end

    it 'returns nil when no match is found in the log line' do
      log_line = ''
      tokens = preprocessor.token_spliter(log_line)
      expect(tokens).to be_nil
    end

    it 'handles log lines with masked sensitive data' do
      log_line = '2023-01-01 10:00:00 Sensitive Data 123-45-6789'
      tokens = preprocessor.token_spliter(log_line)
      expect(tokens).to include('<*>')
      expect(tokens).not_to include('123-45-6789')
    end
  end

  describe '#upload_grams_to_gram_dict' do
    let(:tokens) { %w[token1 token2 token3] }

    before do
      allow(gram_dict).to receive(:single_gram_upload)
      allow(gram_dict).to receive(:double_gram_upload)
      allow(gram_dict).to receive(:tri_gram_upload)
      preprocessor.upload_grams_to_gram_dict(tokens)
    end

    it 'uploads single grams for each token' do
      tokens.each do |token|
        expect(gram_dict).to have_received(:single_gram_upload).with(token)
      end
    end

    it 'uploads digrams for consecutive tokens' do
      expect(gram_dict).to have_received(:double_gram_upload).with('token1^token2')
      expect(gram_dict).to have_received(:double_gram_upload).with('token2^token3')
    end

    it 'uploads trigrams for every three consecutive tokens' do
      expect(gram_dict).to have_received(:tri_gram_upload).with('token1^token2^token3')
    end

    context 'when tokens array is empty' do
      let(:tokens) { [] }

      it 'does not upload any grams' do
        expect(gram_dict).not_to have_received(:single_gram_upload)
        expect(gram_dict).not_to have_received(:double_gram_upload)
        expect(gram_dict).not_to have_received(:tri_gram_upload)
      end
    end
  end
end
