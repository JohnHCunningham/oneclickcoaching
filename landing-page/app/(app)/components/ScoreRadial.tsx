'use client'

import { Doughnut } from 'react-chartjs-2'
import { Chart as ChartJS, ArcElement, Tooltip } from 'chart.js'

ChartJS.register(ArcElement, Tooltip)

interface ScoreRadialProps {
  score: number
  maxScore?: number
  size?: number
  label?: string
}

export default function ScoreRadial({ score, maxScore = 10, size = 160, label }: ScoreRadialProps) {
  const percentage = (score / maxScore) * 100
  const color = score >= 7 ? '#10C3B0' : score >= 5 ? '#F4B03A' : '#E84C88'

  const data = {
    datasets: [
      {
        data: [percentage, 100 - percentage],
        backgroundColor: [color, 'rgba(255,255,255,0.05)'],
        borderWidth: 0,
        cutout: '80%',
      },
    ],
  }

  const options = {
    responsive: false,
    plugins: {
      tooltip: { enabled: false },
    },
  }

  return (
    <div className="relative inline-flex items-center justify-center" style={{ width: size, height: size }}>
      <Doughnut data={data} options={options} width={size} height={size} />
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span className="text-3xl font-bold" style={{ color }}>{score}</span>
        {label && <span className="text-xs text-light-muted mt-0.5">{label}</span>}
      </div>
    </div>
  )
}
