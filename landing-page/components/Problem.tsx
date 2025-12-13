'use client'

import { motion } from 'framer-motion'

const problems = [
  {
    title: 'Inconsistent Execution',
    description: 'Your reps attended the training. They have the playbook. But on actual calls, they forget the pain funnel, skip the up-front contract, and jump straight to pitching.',
    icon: '❌'
  },
  {
    title: 'Coaching That Doesn\'t Scale',
    description: 'You can\'t listen to every call. Manual call reviews take hours. By the time you give feedback, the opportunity is already lost.',
    icon: '⏰'
  },
  {
    title: 'No Visibility Into What\'s Working',
    description: 'You see the numbers (dials, meetings, close rate) but you don\'t know WHY deals are won or lost. Which part of your methodology is breaking down?',
    icon: '🔍'
  }
]

const Problem = () => {
  return (
    <section className="section-padding bg-navy">
      <div className="container-custom">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="text-center mb-16"
        >
          <h2 className="text-4xl md:text-5xl font-bold mb-6">
            Your Sales Team Knows the Methodology.{' '}
            <span className="text-teal">But Are They Actually Using It?</span>
          </h2>
        </motion.div>

        <div className="grid md:grid-cols-3 gap-8">
          {problems.map((problem, index) => (
            <motion.div
              key={index}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: index * 0.2 }}
              className="card"
            >
              <div className="text-5xl mb-4">{problem.icon}</div>
              <h3 className="text-xl font-bold mb-4 text-pink">{problem.title}</h3>
              <p className="text-light-muted leading-relaxed">{problem.description}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  )
}

export default Problem
