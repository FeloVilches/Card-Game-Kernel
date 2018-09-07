require_relative '../../container'
require_relative '../../card'
require_relative '../../global_hooks'
require_relative '../../card_kernel'
require 'rydux'
require './card.rb'

class StateChangerCard < Card
  def initialize(args)
    super
    on :custom_event, :custom_event
  end

  def custom_event(args)
    set_data action: :push_new_state, arguments: { state_name: :choosing_card, predicate: lambda { |card|
      card_hp = card.attributes[:hp]
      return false if card_hp.nil?
      return false if card_hp < 80
      return true
      }
    }
  end
end

class StateReducer < Rydux::Reducer
  def self.map_state(action, state = { history: [] })
    case action[:type]
    when :push_new_state
      history = state[:history]
      history << action[:payload]
      state.merge(history: history)
    when :pop_state
      history = state[:history]
      history.pop
      state.merge(history: history)
    else
      state
    end
  end
end


Store = Rydux::Store.new(state: StateReducer)


describe CardKernel do
  it "makes a card trigger an event handler, which sets up a new temporary state, which is then removed, and the game continues" do

    set_data_lambda = lambda { |action, arguments| Store.dispatch(type: action, payload: arguments) }
    get_data_lambda = lambda { Store.state }

    card1 = StateChangerCard.new id: 1, set_data_callback: set_data_lambda, get_data_callback: get_data_lambda

    expect(get_data_lambda.call()[:state][:history].length).to be 0

    # The game goes through 3 phases (generic)

    set_data_lambda.call(:push_new_state, { state_name: :stage1 })
    expect(get_data_lambda.call()[:state][:history].length).to be 1

    set_data_lambda.call(:push_new_state, { state_name: :stage2 })
    expect(get_data_lambda.call()[:state][:history].length).to be 2

    set_data_lambda.call(:push_new_state, { state_name: :stage3 })
    expect(get_data_lambda.call()[:state][:history].length).to be 3

    expect(get_data_lambda.call()[:state][:history].last()[:state_name]).to be :stage3

    # Then something happens, and card1 has an event triggered, which dispatches some data that modifies the data store.
    # As a result, a new state is pushed onto the history stack

    card1.trigger_event event: :custom_event, arguments: {}

    # Assert the state name was changed by the card
    expect(get_data_lambda.call()[:state][:history].last()[:state_name]).to be :choosing_card

    # This is state is for choosing a card from the deck, but only certain cards.
    # A predicate (lambda) was passed, so we can use that predicate to filter out non eligible cards.
    # But for now, we are fine just checking there's a predicate stored somewhere.
    expect(get_data_lambda.call()[:state][:history].last()[:predicate].class).to eq Proc

    # The process of choosing a card finished, so we go back to our previous state
    set_data_lambda.call(:pop_state, { })
    expect(get_data_lambda.call()[:state][:history].last()[:state_name]).to be :stage3

    # From here, the user could finish stage3 by doing more things, or simply go straight into stage4.
    # It depends on the particular logic.


  end

end
