
describe Bot::Action do
  let(:type)   { :create_order }
  let(:dest)   { :bitfaker }
  let(:params) { { order: Bot::Order.new('ethusd', 1, 1, :buy) } }
  let(:params_clone) { { order: Bot::Order.new('ethusd', 1, 1, :buy) } }

  it 'creates instruction' do
    action = Bot::Action.new(type, dest, params)

    expect(action.type).to eq(type)
    expect(action.params).to eq(params)
    expect(action.destination).to eq(dest)
  end

  it 'support comparison' do
    action1 = Bot::Action.new(type, dest, params)
    action2 = Bot::Action.new(type, dest, params_clone)
    expect(action1).to eq(action2)
  end
end
