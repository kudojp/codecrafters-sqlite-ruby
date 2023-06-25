RSpec.describe SimplestSqlParser::Parser do
  context "when query includes SELECT, FROM, and WHERE clauses" do
    it "generates the AST, and its #self_and_descendants creates a hash of the tree." do
      ast = described_class.new("SELECT name, address FROM table WHERE id = 12.5").do_parse
      expect(ast.self_and_descendants).to eq({
        "AST::QueryNode()" => {
          "select_clause" => {
            "AST::SelectClauseNode()" => {
              "selected_columns" => [
                {
                  "AST::SelectedColumnNode(alias_name=)" => {
                    "col_def" => {
                      "AST::ColumnNode(type=single_col,name=name)" => {}
                    }
                  }
                },
                {
                  "AST::SelectedColumnNode(alias_name=)" => {
                    "col_def" => {
                      "AST::ColumnNode(type=single_col,name=address)" => {}
                    }
                  }
                },
              ]
            }
          },
          "from_clause" => {
            "AST::FromClauseNode()" => {
              "from_table" => {
                "AST::FromTableNode(alias_name=)" => {
                  "table_def" => {
                    "AST::TableNode(name=table)" => {}
                  }
                }
              }
            }
          },
          "where_clause" => {
            "AST::WhereClauseNode()" => {
              "predicate" => [
                {
                  "AST::ConditionNode(operator=equals)" => {
                    "left" => {
                      "AST::SelectedColumnNode(alias_name=)" => {
                        "col_def" => {
                          "AST::ColumnNode(type=single_col,name=id)" => {}
                        }
                      }
                    },
                    "right" => {
                      "AST::ExpressionNode(value=12.5)" => {}
                    }
                  },
                }
              ]
            }
          },
        }
      })
    end
  end

  context "when query includes SELECT, FROM, and WHERE clauses with COUNT function" do
    it "generates the AST, and its #self_and_descendants creates a hash of the tree." do
      ast = described_class.new("SELECT COUNT(*) FROM table WHERE id = 12").do_parse
      expect(ast.self_and_descendants).to eq({
        "AST::QueryNode()" => {
          "select_clause" => {
            "AST::SelectClauseNode()" => {
              "selected_columns" => [
                {
                  "AST::SelectedColumnNode(alias_name=)" => {
                    "col_def" => {
                      "AST::FunctionNode(type=count)" => {
                        "args" => [
                          "AST::ColumnNode(type=asterisk,name=)" => {}
                        ]
                      }
                    }
                  }
                }
              ]
            }
          },
          "from_clause" => {
            "AST::FromClauseNode()" => {
              "from_table" => {
                "AST::FromTableNode(alias_name=)" => {
                  "table_def" => {
                    "AST::TableNode(name=table)" => {}
                  }
                }
              }
            }
          },
          "where_clause" => {
            "AST::WhereClauseNode()" => {
              "predicate" => [
                {
                  "AST::ConditionNode(operator=equals)" => {
                    "left" => {
                      "AST::SelectedColumnNode(alias_name=)" => {
                        "col_def" => {
                          "AST::ColumnNode(type=single_col,name=id)" => {}
                        }
                      }
                    },
                    "right" => {
                      "AST::ExpressionNode(value=12.0)" => {}
                    }
                  },
                }
              ]
            }
          },
        }
      })
    end
  end
end
