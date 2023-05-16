describe Bot::Command do
  let(:config) { YAML.load_file(File.join(__dir__, '../../../config/strategies.yml'))['strategy'] }

  it 'loads configuration' do
    Bot::Command.load_configuration

    expect(Bot::Configuration.get(:strategy)).to eq(config)
  end
end
